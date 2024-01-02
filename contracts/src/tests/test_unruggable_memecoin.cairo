use openzeppelin::token::erc20::interface::{IERC20, ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, RevertedTransaction, CheatTarget,
    TxInfoMock,
};
use starknet::contract_address::ContractAddressZeroable;
use starknet::{ContractAddress, contract_address_const};
use unruggable::exchanges::{Exchange, SupportedExchanges, ExchangeTrait};
use unruggable::tests::utils::{
    OWNER, NAME, SYMBOL, DEFAULT_INITIAL_SUPPLY, RECIPIENT, SPENDER, deploy_locker, INITIAL_HOLDERS,
    INITIAL_HOLDERS_AMOUNTS, TRANSFER_LIMIT_DELAY, DefaultTxInfoMock,
    deploy_memecoin_through_factory
};
use unruggable::tokens::interface::{
    IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
};

mod test_constructor {
    use UnruggableMemecoin::{
        pre_launch_holders_countContractMemberStateTrait,
        transfer_restriction_delayContractMemberStateTrait, team_allocationContractMemberStateTrait,
        IUnruggableAdditional, IUnruggableMemecoinCamel, IUnruggableMemecoinSnake
    };
    use core::debug::PrintTrait;
    use core::traits::TryInto;
    use openzeppelin::token::erc20::interface::IERC20;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
    use starknet::{ContractAddress, contract_address_const};
    use unruggable::tests::utils::{
        deploy_amm_factory_and_router, deploy_meme_factory_with_owner, deploy_locker,
        deploy_eth_with_owner, OWNER, NAME, SYMBOL, DEFAULT_INITIAL_SUPPLY, INITIAL_HOLDERS,
        INITIAL_HOLDER_1, INITIAL_HOLDER_2, INITIAL_HOLDERS_AMOUNTS, SALT, DefaultTxInfoMock,
        deploy_memecoin_through_factory, ETH_ADDRESS, deploy_memecoin_through_factory_with_owner,
        JEDI_ROUTER_ADDRESS, MEMEFACTORY_ADDRESS, ALICE, BOB, TRANSFER_LIMIT_DELAY, pow_256,
        LOCKER_ADDRESS, JEDI_FACTORY_ADDRESS
    };
    use unruggable::tokens::UnruggableMemecoin;
    use unruggable::tokens::interface::{
        IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };


    #[test]
    fn test_constructor_happy_path() {
        let mut memecoin = UnruggableMemecoin::contract_state_for_testing();

        // Deployer must be the meme factory
        start_prank(CheatTarget::One(snforge_std::test_address()), MEMEFACTORY_ADDRESS());
        UnruggableMemecoin::constructor(
            ref memecoin,
            OWNER(),
            LOCKER_ADDRESS(),
            TRANSFER_LIMIT_DELAY,
            NAME(),
            SYMBOL(),
            DEFAULT_INITIAL_SUPPLY(),
            INITIAL_HOLDERS(),
            INITIAL_HOLDERS_AMOUNTS()
        );

        // External entrypoints
        assert(memecoin.locker_address() == LOCKER_ADDRESS(), 'wrong locker');
        assert(
            memecoin.memecoin_factory_address() == MEMEFACTORY_ADDRESS(), 'wrong factory address'
        );

        // Check internals that must be set upon deployment
        assert(
            memecoin.transfer_restriction_delay.read() == TRANSFER_LIMIT_DELAY,
            'wrong transfer limit delay'
        );
        assert(
            memecoin.team_allocation.read() == 2_100_000 * pow_256(10, 18), 'wrong team allocation'
        ); // 10% of supply
    }

    #[test]
    #[should_panic(expected: ('Holders len dont match amounts',))]
    fn test_constructor_initial_holders_arrays_len_mismatch() {
        let initial_holders: Array<ContractAddress> = array![
            INITIAL_HOLDER_1(),
            INITIAL_HOLDER_2(),
            contract_address_const::<'holder 3'>(),
            contract_address_const::<'holder 4'>()
        ];
        let initial_holders_amounts: Array<u256> = array![50, 40, 10];
        let mut state = UnruggableMemecoin::contract_state_for_testing();
        UnruggableMemecoin::constructor(
            ref state,
            OWNER(),
            LOCKER_ADDRESS(),
            TRANSFER_LIMIT_DELAY,
            NAME(),
            SYMBOL(),
            DEFAULT_INITIAL_SUPPLY(),
            initial_holders.span(),
            initial_holders_amounts.span()
        );
    }

    #[test]
    #[should_panic(expected: ('Max number of holders reached',))]
    fn test_constructor_max_holders_reached() {
        // 11 holders > 10 holders max
        let initial_holders = array![
            INITIAL_HOLDER_1(),
            INITIAL_HOLDER_2(),
            contract_address_const::<52>(),
            contract_address_const::<53>(),
            contract_address_const::<54>(),
            contract_address_const::<55>(),
            contract_address_const::<56>(),
            contract_address_const::<57>(),
            contract_address_const::<58>(),
            contract_address_const::<59>(),
            contract_address_const::<60>(),
        ];
        let initial_holders_amounts: Array<u256> = array![1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
        let mut state = UnruggableMemecoin::contract_state_for_testing();
        UnruggableMemecoin::constructor(
            ref state,
            OWNER(),
            LOCKER_ADDRESS(),
            TRANSFER_LIMIT_DELAY,
            NAME(),
            SYMBOL(),
            DEFAULT_INITIAL_SUPPLY(),
            initial_holders.span(),
            initial_holders_amounts.span()
        );
    }

    #[test]
    #[should_panic(expected: ('Max team allocation reached',))]
    fn test_constructor_too_much_team_alloc_should_fail() {
        let mut calldata = array![
            OWNER().into(), 'locker', TRANSFER_LIMIT_DELAY.into(), NAME().into(), SYMBOL().into()
        ];
        // Allocation over 10% (over 2.1M)
        let alloc_holder_1 = 1_050_000 * pow_256(10, 18);
        let alloc_holder_2 = 1_050_001 * pow_256(10, 18);
        let mut state = UnruggableMemecoin::contract_state_for_testing();
        UnruggableMemecoin::constructor(
            ref state,
            OWNER(),
            LOCKER_ADDRESS(),
            TRANSFER_LIMIT_DELAY,
            NAME(),
            SYMBOL(),
            DEFAULT_INITIAL_SUPPLY(),
            INITIAL_HOLDERS(),
            array![alloc_holder_1, alloc_holder_2].span()
        );
    }
}

mod memecoin_entrypoints {
    use core::zeroable::Zeroable;
    use debug::PrintTrait;
    use openzeppelin::token::erc20::interface::{
        IERC20, ERC20ABIDispatcher, ERC20ABIDispatcherTrait
    };
    use snforge_std::{
        declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, start_warp, stop_warp,
        TxInfoMock
    };
    use starknet::{ContractAddress, contract_address_const};
    use unruggable::exchanges::jediswap_adapter::{
        IJediswapFactory, IJediswapFactoryDispatcher, IJediswapFactoryDispatcherTrait,
        IJediswapRouter, IJediswapRouterDispatcher, IJediswapRouterDispatcherTrait,
        IJediswapPairDispatcher, IJediswapPairDispatcherTrait
    };
    use unruggable::exchanges::{Exchange, SupportedExchanges, ExchangeTrait};
    use unruggable::factory::{IFactory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use unruggable::tests::utils::{
        deploy_amm_factory_and_router, deploy_meme_factory_with_owner, deploy_locker,
        deploy_eth_with_owner, OWNER, NAME, SYMBOL, DEFAULT_INITIAL_SUPPLY, INITIAL_HOLDERS,
        INITIAL_HOLDER_1, INITIAL_HOLDER_2, INITIAL_HOLDERS_AMOUNTS, SALT, DefaultTxInfoMock,
        deploy_memecoin_through_factory, ETH_ADDRESS, deploy_memecoin_through_factory_with_owner,
        JEDI_ROUTER_ADDRESS, MEMEFACTORY_ADDRESS, ALICE, BOB, pow_256, LOCKER_ADDRESS,
        deploy_and_launch_memecoin, TRANSFER_LIMIT_DELAY
    };
    use unruggable::tokens::interface::{
        IUnruggableMemecoin, IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };
    use unruggable::tokens::memecoin::UnruggableMemecoin;

    #[test]
    fn test_launch_memecoin_happy_path() {
        let owner = starknet::get_contract_address();
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory_with_owner(owner);
        let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };

        // The amount supplied as liquidity are the amount
        // held by the memecoin contract pre-launch
        let memecoin_bal_meme = memecoin.balanceOf(memecoin_address);
        let memecoin_bal_eth = eth.balanceOf(memecoin_address);

        // Set a non-zero timestamp, as the default "0" time conflicts with the `is_launched` function
        start_warp(CheatTarget::One(memecoin.contract_address), 1);
        let pool_address = memecoin
            .launch_memecoin(SupportedExchanges::JediSwap, eth.contract_address);
        stop_warp(CheatTarget::One(memecoin.contract_address));

        assert(memecoin.is_launched(), 'should be launched');
        let pool_dispatcher = IJediswapPairDispatcher { contract_address: pool_address };
        let (token_0_reserves, token_1_reserves, _) = pool_dispatcher.get_reserves();
        assert(pool_dispatcher.token0() == memecoin_address, 'wrong token 0 address');
        assert(pool_dispatcher.token1() == eth.contract_address, 'wrong token 1 address');
        assert(token_0_reserves == memecoin_bal_meme, 'wrong pool token reserves');
        assert(token_1_reserves == memecoin_bal_eth, 'wrong pool memecoin reserves');
        let lp_token = ERC20ABIDispatcher { contract_address: pool_address };
        assert(lp_token.balanceOf(memecoin_address) == 0, 'shouldnt have lp tokens');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_launch_memecoin_not_owner() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();
        memecoin.launch_memecoin(SupportedExchanges::JediSwap, ETH_ADDRESS(),);
    }

    #[test]
    #[should_panic(expected: ('Exchange not supported',))]
    fn test_launch_memecoin_amm_not_supported() {
        let owner = starknet::get_contract_address();
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory_with_owner(owner);
        let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };

        let pool_address = memecoin
            .launch_memecoin(SupportedExchanges::Ekubo, eth.contract_address);
    }

    #[test]
    fn test_renounce_ownership_upon_memecoin_launch() {
        let (memecoin, memecoin_address) = deploy_and_launch_memecoin();

        assert(memecoin.owner().is_zero(), 'Still an owner');
    }

    #[test]
    fn test_get_team_allocation() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        let team_alloc = memecoin.get_team_allocation();
        // Team alloc is set to 10% in test utils
        assert(team_alloc == 2_100_000 * pow_256(10, 18), 'Invalid team allocation');
    }

    #[test]
    fn test_memecoin_factory_address() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        assert(
            memecoin.memecoin_factory_address() == MEMEFACTORY_ADDRESS(), 'wrong factory address'
        );
    }

    #[test]
    fn test_locker_address() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        assert(memecoin.locker_address() == LOCKER_ADDRESS(), 'wrong locker address');
    }

    #[test]
    #[should_panic(expected: ('Max buy cap reached',))]
    fn test_transfer_max_percentage() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        // Transfer slightly more than 2% of 21M stokens from owner to ALICE().
        let amount = 420_001 * pow_256(10, 18);
        start_prank(CheatTarget::One(memecoin.contract_address), INITIAL_HOLDER_1());
        let send_amount = memecoin.transfer(ALICE(), amount);
    }

    #[test]
    #[should_panic(expected: ('Max buy cap reached',))]
    fn test_transfer_from_max_percentage() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        let amount = 420_001 * pow_256(10, 18);

        start_prank(CheatTarget::One(memecoin.contract_address), OWNER());
        memecoin.approve(snforge_std::test_address(), amount);
        stop_prank(CheatTarget::One(memecoin.contract_address));

        memecoin.transfer_from(OWNER(), ALICE(), amount);
    }

    #[test]
    #[should_panic(expected: ('Multi calls not allowed',))]
    fn test_transfer_from_multi_call() {
        let (memecoin, memecoin_address) = deploy_and_launch_memecoin();

        let this_address = snforge_std::test_address();

        // Approvals required for transferFrom
        start_prank(CheatTarget::One(memecoin_address), INITIAL_HOLDER_1());
        memecoin.approve(this_address, 1);
        stop_prank(CheatTarget::One(memecoin_address));
        start_prank(CheatTarget::One(memecoin_address), INITIAL_HOLDER_2());
        memecoin.approve(this_address, 1);
        stop_prank(CheatTarget::One(memecoin_address));

        // Transfer token from owner to ALICE() twice - should fail because
        // the tx_hash is the same for both calls
        memecoin.transfer_from(INITIAL_HOLDER_1(), ALICE(), 1);
        memecoin.transfer_from(INITIAL_HOLDER_2(), ALICE(), 1);
    }

    #[test]
    fn test_multi_call_prevention_disallowed_after_delay() {
        let (memecoin, memecoin_address) = deploy_and_launch_memecoin();

        let launch_timestamp = 1;

        // setting block timestamp >= launch_time + transfer_delay. Transfer should succeed
        // as multi calls to the same recipient are allowed after the delay
        start_warp(
            CheatTarget::One(memecoin.contract_address), launch_timestamp + TRANSFER_LIMIT_DELAY
        );
        start_prank(CheatTarget::One(memecoin.contract_address), INITIAL_HOLDER_1());
        let send_amount = memecoin.transfer_from(INITIAL_HOLDER_1(), ALICE(), 0);
        start_prank(CheatTarget::One(memecoin.contract_address), INITIAL_HOLDER_2());
        let send_amount = memecoin.transfer_from(INITIAL_HOLDER_2(), ALICE(), 0);
    }

    #[test]
    fn test_classic_max_percentage() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        // Transfer 1 token from owner to ALICE().
        start_prank(CheatTarget::One(memecoin_address), INITIAL_HOLDER_1());
        let send_amount = memecoin.transfer(ALICE(), 20);
        assert(memecoin.balanceOf(ALICE()) == 20, 'Invalid balance');
    }
}


mod memecoin_internals {
    use UnruggableMemecoin::{
        UnruggableMemecoinInternalImpl, SnakeEntrypoints, UnruggableEntrypoints,
        MAX_HOLDERS_BEFORE_LAUNCH
    };
    use core::debug::PrintTrait;
    use openzeppelin::token::erc20::interface::IERC20;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
    use starknet::{ContractAddress, contract_address_const};
    use super::{TxInfoMock};
    use unruggable::tests::utils::{
        deploy_amm_factory_and_router, deploy_meme_factory_with_owner, deploy_locker,
        deploy_eth_with_owner, OWNER, NAME, SYMBOL, DEFAULT_INITIAL_SUPPLY, INITIAL_HOLDERS,
        INITIAL_HOLDER_1, INITIAL_HOLDER_2, INITIAL_HOLDERS_AMOUNTS, SALT, DefaultTxInfoMock,
        deploy_memecoin_through_factory, ETH_ADDRESS, deploy_memecoin_through_factory_with_owner,
        JEDI_ROUTER_ADDRESS, MEMEFACTORY_ADDRESS, ALICE, BOB
    };
    use unruggable::tokens::interface::{
        IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };
    use unruggable::tokens::memecoin::UnruggableMemecoin;

    #[test]
    fn test__transfer_recipients_equal_holder_cap() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        // set INITIAL_HOLDER_1() as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), INITIAL_HOLDER_1());

        let mut index = 0;
        loop {
            // MAX_HOLDERS_BEFORE_LAUNCH - 2 because there are 2 initial holders
            if index == MAX_HOLDERS_BEFORE_LAUNCH - 2 {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // creating and setting unique tx_hash here 
            let mut tx_info: TxInfoMock = Default::default();
            tx_info.transaction_hash = Option::Some(index.into() + 9999);
            snforge_std::start_spoof(CheatTarget::One(memecoin.contract_address), tx_info);

            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            // Check recipient balance. Should be equal to 1.
            let recipient_balance = memecoin.balanceOf(unique_recipient);
            assert(recipient_balance == 1, 'Invalid balance recipient');

            index += 1;
        };
    }

    #[test]
    fn test__transfer_existing_holders() {
        /// pre launch holder number should not change when
        /// transfer is done to recipient(s) who already have tokens

        /// to test this, we are going to continously self transfer tokens
        /// and ensure that we can transfer more than `MAX_HOLDERS_BEFORE_LAUNCH` times

        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        // set INITIAL_HOLDER_1() as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), INITIAL_HOLDER_1());

        let mut index = 0;
        loop {
            if index == MAX_HOLDERS_BEFORE_LAUNCH {
                break;
            }

            // creating and setting unique tx_hash here 
            let mut tx_info: TxInfoMock = Default::default();
            tx_info.transaction_hash = Option::Some(index.into() + 9999);
            snforge_std::start_spoof(CheatTarget::One(memecoin.contract_address), tx_info);

            // Self transfer tokens
            memecoin.transfer(INITIAL_HOLDER_2(), 1);

            index += 1;
        };
    }

    #[test]
    #[should_panic(expected: ('Max number of holders reached',))]
    fn test__transfer_above_holder_cap() {
        let (memecoin, memecoin_address) = deploy_memecoin_through_factory();

        // set INITIAL_HOLDER_1() as caller to distribute tokens
        start_prank(CheatTarget::One(memecoin.contract_address), INITIAL_HOLDER_1());

        let mut index = 0;
        loop {
            if index == MAX_HOLDERS_BEFORE_LAUNCH {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // creating and setting unique tx_hash here 
            let mut tx_info: TxInfoMock = Default::default();
            tx_info.transaction_hash = Option::Some(index.into() + 9999);
            snforge_std::start_spoof(CheatTarget::One(memecoin.contract_address), tx_info);
            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            index += 1;
        };
    }

    #[test]
    #[ignore]
    //TODO: implement this test
    fn test__transfer_no_holder_cap_after_launch() {
        // The initial call to launch the memecoin should be made by the owner.
        // However the subsequent calls should be made by the router - as such,
        // we can't mock the owner using starknet-foundry.
        // We simply set the test contract as the owner of the memecoin.
        let owner = starknet::get_contract_address();
        let initial_holders_amounts = array![50, 30,].span();

        let mut calldata = array![owner.into(), NAME().into(), SYMBOL().into()];
        Serde::serialize(@DEFAULT_INITIAL_SUPPLY(), ref calldata);
        Serde::serialize(@INITIAL_HOLDERS(), ref calldata);
        Serde::serialize(@initial_holders_amounts, ref calldata);
        let contract = declare('UnruggableMemecoin');
        let contract_address = contract.deploy(@calldata).expect('failed to deploy memecoin');
        let memecoin = IUnruggableMemecoinDispatcher { contract_address };

        // set owner as caller to launch the token
        start_prank(CheatTarget::All, owner);

        // NOTE:
        // 1. The initial call to `memecoin_address` should be made by the owner.
        // 2. Subsequently, the router needs to call memecoin to transfer tokens to the pool.
        // 3. The second call to `memecoin_address` should be made by the router.
        //    However, note that the prank still designates owner as the caller.
        // `set_contract_address()` from starknet cannot be used in this context.
        // related issue: https://github.com/foundry-rs/starknet-foundry/issues/1402

        // start_prank(CheatTarget::One(memecoin_address), router_address);
        // start_prank(CheatTarget::One(router_address), memecoin_address);
        // memecoin
        //     .launch_memecoin(
        //         SupportedExchanges::JediSwap, counterparty_token_address, 20000000000000000, 1 * ETH_UNIT_DECIMALS
        //     );
        // TODO: call launch_memecoin() with params
        // memecoin.launch_memecoin();

        // set INITIAL_HOLDER_1() as caller to distribute tokens
        start_prank(CheatTarget::All, INITIAL_HOLDER_1());

        let mut index = 0;
        loop {
            if index == MAX_HOLDERS_BEFORE_LAUNCH {
                break;
            }

            // create a unique address
            let unique_recipient: ContractAddress = (index.into() + 9999).try_into().unwrap();

            // creating and setting unique tx_hash here 
            let mut tx_info: TxInfoMock = Default::default();
            tx_info.transaction_hash = Option::Some(index.into() + 9999);
            snforge_std::start_spoof(CheatTarget::One(memecoin.contract_address), tx_info);

            // Transfer 1 token to the unique recipient
            memecoin.transfer(unique_recipient, 1);

            index += 1;
        };
    }
}

