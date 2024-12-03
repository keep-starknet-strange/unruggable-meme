//! `UnruggableMemecoin` is an ERC20 token has additional features to prevent rug pulls.
use starknet::ContractAddress;

use unruggable::exchanges::ekubo_adapter::EkuboPoolParameters;

#[derive(Copy, Drop, starknet::Store, Serde)]
enum LiquidityType {
    JediERC20: ContractAddress,
    StarkDeFiERC20: ContractAddress,
    EkuboNFT: u64
}

#[derive(Copy, Drop, starknet::Store, Serde)]
struct EkuboLiquidityParameters {
    ekubo_pool_parameters: EkuboPoolParameters,
    quote_address: ContractAddress,
}

#[derive(Copy, Drop, starknet::Store, Serde)]
struct JediswapLiquidityParameters {
    quote_address: ContractAddress,
    quote_amount: u256,
}

#[derive(Copy, Drop, starknet::Store, Serde)]
struct StarkDeFiLiquidityParameters {
    quote_address: ContractAddress,
    quote_amount: u256,
}

#[derive(Copy, Drop, starknet::Store, Serde)]
enum LiquidityParameters {
    Ekubo: EkuboLiquidityParameters,
    Jediswap: (JediswapLiquidityParameters, ContractAddress),
    StarkDeFi: (StarkDeFiLiquidityParameters, ContractAddress),
}

#[starknet::contract]
mod UnruggableMemecoin {
    use core::box::BoxTrait;
    use core::traits::TryInto;
    use core::zeroable::Zeroable;
    use debug::PrintTrait;
    use integer::BoundedInt;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::interface::IOwnable;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::erc20::ERC20Component::InternalTrait;

    use openzeppelin::token::erc20::interface::{
        IERC20, IERC20Metadata, ERC20ABIDispatcher, ERC20ABIDispatcherTrait
    };
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_tx_info,
        get_block_timestamp, get_block_info
    };
    use super::{LiquidityType, LiquidityParameters};

    use unruggable::errors;
    use unruggable::exchanges::jediswap_adapter::{
        IJediswapFactoryDispatcher, IJediswapFactoryDispatcherTrait, IJediswapRouterDispatcher,
        IJediswapRouterDispatcherTrait
    };
    use unruggable::exchanges::{SupportedExchanges};
    use unruggable::factory::{IFactory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use unruggable::locker::{ILockManagerDispatcher, ILockManagerDispatcherTrait};
    use unruggable::token::interface::{
        IUnruggableMemecoinSnake, IUnruggableMemecoinCamel, IUnruggableAdditional
    };
    use unruggable::utils::math::PercentageMath;

    // Components.
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Constants.
    /// The minimum maximum percentage of the supply that can be bought at once.
    const MIN_MAX_PERCENTAGE_BUY_LAUNCH: u16 = 50; // 0.5%

    #[storage]
    struct Storage {
        marker_v_0: (),
        team_allocation: u256,
        tx_hash_tracker: LegacyMap<ContractAddress, felt252>,
        transfer_restriction_delay: u64,
        launch_time: u64,
        launch_block_number: u64,
        launch_liquidity_parameters: Option<LiquidityParameters>,
        factory_contract: ContractAddress,
        liquidity_type: Option<LiquidityType>,
        max_percentage_buy_launch: u16,
        // Components.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    /// Constructor called once when the contract is deployed.
    /// # Arguments
    /// * `owner` - The owner of the contract.
    /// * `name` - The name of the token.
    /// * `symbol` - The symbol of the token.
    /// * `initial_supply` - The initial supply of the token.
    /// * `initial_holders` - The initial holders of the token, an array of holder_address
    /// * `initial_holders_amounts` - The initial amounts of tokens minted to the initial holders, an array of amounts
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
    ) {
        assert(owner.is_non_zero(), errors::OWNER_IS_ZERO);
        self.erc20.initializer(name, symbol);

        self.ownable.initializer(owner);

        self.liquidity_type.write(Option::None);

        // Initialize the token / internal logic
        self.initializer(factory_address: get_caller_address(), :initial_supply,);
    }

    #[abi(embed_v0)]
    impl UnruggableEntrypoints of IUnruggableAdditional<ContractState> {
        fn is_launched(self: @ContractState) -> bool {
            self.launch_time.read().is_non_zero()
        }

        fn launched_at_block_number(self: @ContractState) -> u64 {
            self.launch_block_number.read()
        }

        fn launched_with_liquidity_parameters(self: @ContractState) -> Option<LiquidityParameters> {
            self.launch_liquidity_parameters.read()
        }

        /// Returns the team allocation in tokens.
        fn get_team_allocation(self: @ContractState) -> u256 {
            self.team_allocation.read()
        }

        fn memecoin_factory_address(self: @ContractState) -> ContractAddress {
            self.factory_contract.read()
        }

        fn liquidity_type(self: @ContractState) -> Option<LiquidityType> {
            self.liquidity_type.read()
        }

        fn set_launched(
            ref self: ContractState,
            liquidity_type: LiquidityType,
            liquidity_params: LiquidityParameters,
            transfer_restriction_delay: u64,
            max_percentage_buy_launch: u16,
            team_allocation: u256,
        ) {
            self.assert_only_factory();
            assert(!self.is_launched(), errors::ALREADY_LAUNCHED);
            assert(
                max_percentage_buy_launch >= MIN_MAX_PERCENTAGE_BUY_LAUNCH,
                errors::MAX_PERCENTAGE_BUY_LAUNCH_TOO_LOW
            );

            // save liquidity params and launch block number
            self.launch_block_number.write(get_block_info().unbox().block_number);
            self.launch_liquidity_parameters.write(Option::Some(liquidity_params));

            self.liquidity_type.write(Option::Some(liquidity_type));
            self.launch_time.write(get_block_timestamp());
            self.team_allocation.write(team_allocation);

            // Enable a transfer limit - until this time has passed,
            // transfers are limited to a certain amount.
            self.max_percentage_buy_launch.write(max_percentage_buy_launch);
            self.transfer_restriction_delay.write(transfer_restriction_delay);

            // renounce ownership
            self.ownable._transfer_ownership(0.try_into().unwrap());
        }
    }

    #[abi(embed_v0)]
    impl SnakeEntrypoints of IUnruggableMemecoinSnake<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self.erc20._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount)
        }
    }

    #[abi(embed_v0)]
    impl CamelEntrypoints of IUnruggableMemecoinCamel<ContractState> {
        fn totalSupply(self: @ContractState) -> u256 {
            self.total_supply()
        }
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }
        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.transfer_from(sender, recipient, amount)
        }
    }

    //
    // Internal
    //
    #[generate_trait]
    impl UnruggableMemecoinInternalImpl of UnruggableMemecoinInternalTrait {
        fn assert_only_factory(self: @ContractState) {
            assert(get_caller_address() == self.factory_contract.read(), errors::NOT_FACTORY);
        }

        /// Initializes the state of the memecoin contract.
        ///
        /// This function sets the factory contract address, enables a transfer limit delay,
        /// checks and allocates the team supply of the memecoin, and mints the remaining supply to the factory.
        ///
        /// # Arguments
        ///
        /// * `factory_address` - The address of the factory contract.
        /// * `initial_supply` - The initial supply of the memecoin.
        /// * `initial_holders` - A span of addresses that will hold the memecoin initially.
        /// * `initial_holders_amounts` - A span of amounts corresponding to the initial holders.
        ///
        /// # Returns
        /// * `u256` - The total amount of memecoin allocated to the team.
        fn initializer(
            ref self: ContractState, factory_address: ContractAddress, initial_supply: u256,
        ) {
            // Internal Registry
            self.factory_contract.write(factory_address);

            // Mint remaining supply to the contract
            self.erc20._mint(recipient: factory_address, amount: initial_supply);
        }

        /// Transfers tokens from the sender to the recipient, by applying relevant restrictions.
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // When we launch on jediswap on the factory, we invoke the add_liquidity() of the router,
            // which performs a transferFrom() to send the tokens to the pool.
            // Therefore, we need to bypass this validation if the sender is the factory contract.
            if sender != self.factory_contract.read() {
                self.apply_transfer_restrictions(sender, recipient, amount)
            }
            self.erc20._transfer(sender, recipient, amount);
        }

        /// Applies the relevant transfer restrictions, if the timing for restrictions has not elapsed yet.
        /// - Before launch, the number of holders and their allocation does not exceed the maximum allowed.
        /// - After launch, the transfer amount does not exceed a certain percentage of the total supply.
        /// and the recipient has not already received tokens in the current transaction.
        ///
        /// By returning early if the transaction performed is not a direct buy from the pair / ekubo core,
        /// we ensure that the restrictions only trigger once, when the coin is moved from pools.
        /// As such, this keeps compatibility with aggregators and routers that perform multiple transfers
        /// when swapping tokens.
        ///
        /// # Arguments
        ///
        /// * `sender` - The address of the sender.
        /// * `recipient` - The address of the recipient.
        /// * `amount` - The amount of tokens to transfer.
        fn apply_transfer_restrictions(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            if self.is_after_time_restrictions() {
                return;
            }

            //TODO(audit): shouldn't ever happen since factory has all the supply
            if !self.is_launched() {
                return;
            }
            // Safe unwrap as we already checked that the coin is launched,
            // thus the liquidity type is not none.
            match self.liquidity_type.read().unwrap() {
                LiquidityType::JediERC20(pair) => {
                    if (get_caller_address() != pair) {
                        // When buying from jediswap, the caller_address is the pair,
                        // so we return early if the caller is not the pair to not apply restrictions.
                        return;
                    }
                },
                LiquidityType::StarkDeFiERC20(pair) => {
                    if (get_caller_address() != pair) {
                        // same as above
                        return;
                    }
                },
                LiquidityType::EkuboNFT(_) => {
                    let factory = IFactoryDispatcher {
                        contract_address: self.factory_contract.read()
                    };
                    let ekubo_core_address = factory.ekubo_core_address();
                    if (get_caller_address() != ekubo_core_address) {
                        // When buying from Ekubo, the token is transferred from Ekubo Core
                        // to the recipient, so we return early if the caller is not Ekubo Core.
                        return;
                    }
                }
            }

            assert(
                amount <= self
                    .total_supply()
                    .percent_mul(self.max_percentage_buy_launch.read().into()),
                'Max buy cap reached'
            );
        }

        /// Checks if the current time is after the launch period.
        ///
        /// # Returns
        ///
        /// * `bool` - True if the current time is after the launch period, false otherwise.
        ///
        fn is_after_time_restrictions(self: @ContractState) -> bool {
            let current_time = get_block_timestamp();
            self.is_launched()
                && current_time >= (self.launch_time.read()
                    + self.transfer_restriction_delay.read())
        }
    }
}
