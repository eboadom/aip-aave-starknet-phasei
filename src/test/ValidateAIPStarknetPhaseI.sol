// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {BaseTest, console} from "./base/BaseTest.sol";
import {PayloadAaveStarknetPhaseI, ICollector, IOwnable, LibPropConstants} from "../PayloadAaveStarknetPhaseI.sol";

interface IAaveGov {
    struct ProposalWithoutVotes {
        uint256 id;
        address creator;
        address executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        uint256 startBlock;
        uint256 endBlock;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        address strategy;
        bytes32 ipfsHash;
    }

    enum ProposalState {
        Pending,
        Canceled,
        Active,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct SPropCreateParams {
        address executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        bytes32 ipfsHash;
    }

    function create(
        address executor,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls,
        bytes32 ipfsHash
    ) external returns (uint256);

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external payable;

    function submitVote(uint256 proposalId, bool support) external;

    function getProposalById(uint256 proposalId)
        external
        view
        returns (ProposalWithoutVotes memory);

    function getProposalState(uint256 proposalId)
        external
        view
        returns (ProposalState);
}

contract ValidateAIPStarknetPhaseI is BaseTest {
    address internal constant AAVE_TREASURY =
        0x25F2226B597E8F9514B3F68F00f494cF4f286491;

    IAaveGov internal constant GOV =
        IAaveGov(0xEC568fffba86c094cf06b22134B23074DFE2252c);

    address SHORT_EXECUTOR = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;

    function setUp() public {}

    function testProposal() public {
        address payload = address(new PayloadAaveStarknetPhaseI());

        address[] memory targets = new address[](1);
        targets[0] = payload;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "execute()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        uint256 proposalId = _createProposal(
            IAaveGov.SPropCreateParams({
                executor: SHORT_EXECUTOR,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                withDelegatecalls: withDelegatecalls,
                ipfsHash: bytes32(0)
            })
        );

        uint256 recipientUsdcBefore = LibPropConstants.USDC.balanceOf(
            LibPropConstants.FUNDS_RECIPIENT
        );
        uint256 recipientWethBefore = LibPropConstants.WETH.balanceOf(
            LibPropConstants.FUNDS_RECIPIENT
        );

        vm.deal(AAVE_TREASURY, 1 ether);
        vm.startPrank(AAVE_TREASURY);
        vm.roll(block.number + 1);
        GOV.submitVote(proposalId, true);
        uint256 endBlock = GOV.getProposalById(proposalId).endBlock;
        vm.roll(endBlock + 1);
        GOV.queue(proposalId);
        uint256 executionTime = GOV.getProposalById(proposalId).executionTime;
        vm.warp(executionTime + 1);
        GOV.execute(proposalId);
        vm.stopPrank();

        _validatePhaseIFunds(recipientUsdcBefore, recipientWethBefore);
        address newControllerOfCollector = _validateNewCollector();
        _validateNewControllerOfCollector(ICollector(newControllerOfCollector));
    }

    function _createProposal(IAaveGov.SPropCreateParams memory params)
        internal
        returns (uint256)
    {
        vm.deal(AAVE_TREASURY, 1 ether);
        vm.startPrank(AAVE_TREASURY);
        uint256 proposalId = GOV.create(
            params.executor,
            params.targets,
            params.values,
            params.signatures,
            params.calldatas,
            params.withDelegatecalls,
            params.ipfsHash
        );
        vm.stopPrank();
        return proposalId;
    }

    function _validatePhaseIFunds(
        uint256 recipientUsdcBefore,
        uint256 recipientWethBefore
    ) internal view {
        require(
            LibPropConstants.USDC.balanceOf(LibPropConstants.FUNDS_RECIPIENT) ==
                LibPropConstants.USDC_AMOUNT + recipientUsdcBefore,
            "INVALID_RECIPIENT_USDC_BALANCE"
        );
        require(
            LibPropConstants.WETH.balanceOf(LibPropConstants.FUNDS_RECIPIENT) ==
                LibPropConstants.ETH_AMOUNT + recipientWethBefore,
            "INVALID_RECIPIENT_WETH_BALANCE"
        );
    }

    function _validateNewControllerOfCollector(ICollector controllerOfCollector)
        internal
    {
        require(
            IOwnable(address(controllerOfCollector)).owner() == SHORT_EXECUTOR,
            "NEW_CONTROLLER_TESTS: INVALID_OWNER"
        );

        // Negative tests of ownership
        vm.startPrank(AAVE_TREASURY);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        controllerOfCollector.transfer(LibPropConstants.AUSDC, address(0), 666);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        controllerOfCollector.approve(LibPropConstants.AWETH, address(0), 999);
        vm.stopPrank();

        // Positive ownership tests
        vm.startPrank(SHORT_EXECUTOR);
        uint256 balanceMockRecipientBefore = LibPropConstants.AUSDC.balanceOf(
            address(1)
        );
        controllerOfCollector.transfer(LibPropConstants.AUSDC, address(1), 666);
        require(
            _almostEqual(
                LibPropConstants.AUSDC.balanceOf(address(1)),
                balanceMockRecipientBefore + 666
            ),
            "NEW_CONTROLLER_TESTS : INVALID_POST_TRANSFER_BALANCE"
        );

        controllerOfCollector.approve(LibPropConstants.AWETH, address(1), 777);
        require(
            (LibPropConstants.AWETH.allowance(
                address(LibPropConstants.COLLECTOR_V2_PROXY),
                address(1)
            ) == 777),
            "NEW_CONTROLLER_TESTS : INVALID_POST_TRANSFER_ALLOWANCE"
        );
        vm.stopPrank();
    }

    function _validateNewCollector() internal returns (address) {
        vm.startPrank(SHORT_EXECUTOR);

        // Only the admin can call the admin() view function, so acts as assert of correctness
        LibPropConstants.COLLECTOR_V2_PROXY.admin();
        require(
            LibPropConstants.COLLECTOR_V2_PROXY.implementation() ==
                address(LibPropConstants.NEW_COLLECTOR_IMPL),
            "NEW_COLLECTOR_TESTS : INVALID_NEW_COLLECTOR_IMPL"
        );
        vm.stopPrank();

        require(
            LibPropConstants.NEW_COLLECTOR_IMPL.REVISION() == 2,
            "NEW_COLLECTOR_TESTS : INVALID_COLLECTOR_IMPL_REVISION"
        );

        address controllerOfCollector = ICollector(
            address(LibPropConstants.COLLECTOR_V2_PROXY)
        ).getFundsAdmin();

        ICollector collectorProxy = ICollector(
            address(LibPropConstants.COLLECTOR_V2_PROXY)
        );

        // Negative tests of ownership
        vm.startPrank(AAVE_TREASURY);
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        collectorProxy.transfer(LibPropConstants.AUSDC, address(0), 666);
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        collectorProxy.approve(LibPropConstants.AWETH, address(0), 999);
        vm.stopPrank();

        // Positive ownership tests
        vm.startPrank(controllerOfCollector);
        uint256 balanceMockRecipientBefore = LibPropConstants.AUSDC.balanceOf(
            address(1)
        );
        collectorProxy.transfer(LibPropConstants.AUSDC, address(1), 666);
        require(
            _almostEqual(
                LibPropConstants.AUSDC.balanceOf(address(1)),
                balanceMockRecipientBefore + 666
            ),
            "NEW_COLLECTOR_TESTS : INVALID_POST_TRANSFER_BALANCE"
        );

        uint256 allowanceMockRecipientBefore = LibPropConstants.AWETH.allowance(
            address(collectorProxy),
            address(1)
        );
        collectorProxy.approve(LibPropConstants.AWETH, address(1), 666);
        require(
            LibPropConstants.AWETH.allowance(
                address(collectorProxy),
                address(1)
            ) == allowanceMockRecipientBefore + 666,
            "NEW_COLLECTOR_TESTS : INVALID_POST_TRANSFER_ALLOWANCE"
        );

        vm.stopPrank();

        // No further initialisation can be done
        vm.startPrank(AAVE_TREASURY);
        vm.expectRevert(
            bytes("Contract instance has already been initialized")
        );
        collectorProxy.initialize(address(1));
        vm.stopPrank();

        return controllerOfCollector;
    }

    /// @dev To contemplate +1/-1 precision issues when rounding, mainly on aTokens
    function _almostEqual(uint256 a, uint256 b) internal pure returns (bool) {
        if (b == 0) {
            return (a == b) || (a == (b + 1));
        } else {
            return (a == b) || (a == (b + 1)) || (a == (b - 1));
        }
    }
}
