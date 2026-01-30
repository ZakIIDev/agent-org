// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @title BountyEscrow (MVP)
/// @notice Simple single-owner bounty escrow.
///         - Owner (human) creates/funds bounties.
///         - Any solver can claim.
///         - Solver submits proof.
///         - Owner accepts -> pays solver.
///         - Owner can cancel before payment.
/// @dev Keep it minimal; add disputes/milestones later.
contract BountyEscrow {
    enum Status {
        Open,
        Claimed,
        Submitted,
        Paid,
        Cancelled
    }

    struct Bounty {
        address creator; // owner at time of creation
        address solver;
        address token; // address(0) = native ETH
        uint256 amount;
        bytes32 metadataHash; // hash of off-chain JSON (incl acceptance criteria)
        uint64 createdAt;
        uint64 deadline; // 0 = none
        Status status;
    }

    error NotOwner();
    error InvalidBounty();
    error BadStatus(Status expected, Status got);
    error DeadlinePassed();
    error AlreadyClaimed();
    error NotSolver();
    error TransferFailed();

    event BountyCreated(uint256 indexed bountyId, address indexed token, uint256 amount, bytes32 metadataHash, uint64 deadline);
    event BountyClaimed(uint256 indexed bountyId, address indexed solver);
    event BountySubmitted(uint256 indexed bountyId, bytes32 indexed workHash, string proofUrl);
    event BountyPaid(uint256 indexed bountyId, address indexed solver, uint256 amount);
    event BountyCancelled(uint256 indexed bountyId);

    address public immutable owner;
    uint256 public bountyCount;
    mapping(uint256 => Bounty) public bounties;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Create a bounty funded with native ETH.
    function createEthBounty(bytes32 metadataHash, uint64 deadline) external payable onlyOwner returns (uint256 bountyId) {
        if (msg.value == 0) revert TransferFailed();
        bountyId = ++bountyCount;
        bounties[bountyId] = Bounty({
            creator: msg.sender,
            solver: address(0),
            token: address(0),
            amount: msg.value,
            metadataHash: metadataHash,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            status: Status.Open
        });
        emit BountyCreated(bountyId, address(0), msg.value, metadataHash, deadline);
    }

    /// @notice Create a bounty funded with an ERC20 token.
    function createErc20Bounty(address token, uint256 amount, bytes32 metadataHash, uint64 deadline) external onlyOwner returns (uint256 bountyId) {
        if (token == address(0) || amount == 0) revert TransferFailed();
        // pull funds in
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        bountyId = ++bountyCount;
        bounties[bountyId] = Bounty({
            creator: msg.sender,
            solver: address(0),
            token: token,
            amount: amount,
            metadataHash: metadataHash,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            status: Status.Open
        });
        emit BountyCreated(bountyId, token, amount, metadataHash, deadline);
    }

    function claim(uint256 bountyId) external {
        Bounty storage b = _get(bountyId);
        if (b.status != Status.Open) revert BadStatus(Status.Open, b.status);
        if (b.deadline != 0 && block.timestamp > b.deadline) revert DeadlinePassed();
        b.solver = msg.sender;
        b.status = Status.Claimed;
        emit BountyClaimed(bountyId, msg.sender);
    }

    function submit(uint256 bountyId, bytes32 workHash, string calldata proofUrl) external {
        Bounty storage b = _get(bountyId);
        if (msg.sender != b.solver) revert NotSolver();
        if (b.status != Status.Claimed) revert BadStatus(Status.Claimed, b.status);
        b.status = Status.Submitted;
        emit BountySubmitted(bountyId, workHash, proofUrl);
    }

    function acceptAndPay(uint256 bountyId) external onlyOwner {
        Bounty storage b = _get(bountyId);
        if (b.status != Status.Submitted) revert BadStatus(Status.Submitted, b.status);
        b.status = Status.Paid;

        if (b.token == address(0)) {
            (bool ok, ) = b.solver.call{value: b.amount}("");
            if (!ok) revert TransferFailed();
        } else {
            bool ok = IERC20(b.token).transfer(b.solver, b.amount);
            if (!ok) revert TransferFailed();
        }

        emit BountyPaid(bountyId, b.solver, b.amount);
    }

    function cancel(uint256 bountyId) external onlyOwner {
        Bounty storage b = _get(bountyId);
        if (b.status == Status.Paid || b.status == Status.Cancelled) revert BadStatus(Status.Open, b.status);
        b.status = Status.Cancelled;

        // refund to owner
        if (b.token == address(0)) {
            (bool ok, ) = owner.call{value: b.amount}("");
            if (!ok) revert TransferFailed();
        } else {
            bool ok = IERC20(b.token).transfer(owner, b.amount);
            if (!ok) revert TransferFailed();
        }

        emit BountyCancelled(bountyId);
    }

    function _get(uint256 bountyId) internal view returns (Bounty storage b) {
        b = bounties[bountyId];
        if (b.creator == address(0)) revert InvalidBounty();
    }
}
