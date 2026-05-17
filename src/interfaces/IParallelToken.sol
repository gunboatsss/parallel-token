// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.33;

/// @title ParallelToken Interface
/// @notice Interface for the ParallelToken contract, a parallelized token system that
///         represents ERC20 tokens as discrete IDs with push/pull transfer patterns.
///         Fee-on-transfer and rebasing tokens are not supported.
interface IParallelToken {
    /// @notice Data associated with a token ID
    /// @param underlyingERC20 The ERC20 token backing this token ID
    /// @param owner The current owner of this token ID
    /// @param amount The amount of the underlying ERC20 represented by this ID
    struct TokenData {
        address underlyingERC20;
        address owner;
        uint256 amount;
    }

    /// @notice Emitted when a new token ID is minted
    /// @param id The newly minted token ID
    /// @param owner The owner of the minted token
    /// @param balance The initial amount of the underlying token
    event Mint(uint256 indexed id, address indexed owner, uint256 balance);

    /// @notice Emitted when a token ID is burned (redeemed for the underlying)
    /// @param id The burned token ID
    /// @param owner The owner that burned the token
    /// @param balance The amount of underlying released
    event Burn(uint256 indexed id, address indexed owner, uint256 balance);

    /// @notice Emitted when multiple token IDs are merged into one
    /// @param id The destination token ID that received the merged amounts
    /// @param newAmount The total amount after merging
    event Merge(uint256 indexed id, uint256 newAmount);

    /// @notice Emitted when an approval is set for a specific token ID
    /// @param owner The token owner
    /// @param spender The approved spender
    /// @param id The approved token ID
    /// @param approval Whether the approval is granted or revoked
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, bool approval);

    /// @notice Emitted when an operator is set
    /// @param owner The token owner
    /// @param operator The operator address
    /// @param approval Whether the operator is approved or revoked
    event OperatorSet(address indexed owner, address indexed operator, bool approval);

    /// @notice Emitted when a token ID is transferred between owners
    /// @param caller The address that initiated the transfer
    /// @param from The previous owner
    /// @param to The new owner
    /// @param id The transferred token ID
    /// @param memo Optional data attached to the transfer
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, bytes memo);

    /// @notice Thrown when trying to mint with zero amount
    error ZeroAmount();

    /// @notice Thrown when an invalid zero address is provided
    error ZeroAddress();

    /// @notice Thrown when there is an unexpected ID collision during minting
    error Collusion();

    /// @notice Thrown when an array parameter has zero length
    error ZeroLength();

    /// @notice Thrown when the caller is not the token owner for an operation
    error NotAOwner();

    /// @notice Thrown when attempting to merge/burn tokens with different underlying ERC20s
    /// @param address1 The first underlying address
    /// @param address2 The second (mismatched) underlying address
    error MixedAddress(address address1, address address2);

    /// @notice Thrown when attempting an invalid merge (e.g. merging into itself)
    error InvalidMerge();

    /// @notice Thrown when array parameters have mismatching lengths
    error InvalidLength();

    /// @notice Thrown when a caller lacks authorization for the operation
    error Unauthorized();

    /// @notice Thrown when an unsupported fee-on-transfer or rebasing token is used
    error FeeOnTransferToken();

    /// @notice Get the token data for a given ID
    /// @param id The token ID to query
    /// @return underlyingERC20 The address of the underlying ERC20 token
    /// @return owner The current owner of the token ID
    /// @return amount The amount of the underlying ERC20 represented
    function tokenData(uint256 id) external view returns (address underlyingERC20, address owner, uint256 amount);

    /// @notice Get the current nonce for an address (used for deterministic ID generation)
    /// @param owner The address to query
    /// @return The current nonce value
    function nonces(address owner) external view returns (uint256);

    /// @notice Check if a spender is approved for a specific token ID
    /// @param owner The token owner
    /// @param spender The address to check
    /// @param id The token ID
    /// @return Whether the spender is approved for that ID
    function allowance(address owner, address spender, uint256 id) external view returns (bool);

    /// @notice Check if an operator is approved for all tokens of an owner
    /// @param owner The token owner
    /// @param operator The address to check
    /// @return Whether the operator is approved
    function isOperator(address owner, address operator) external view returns (bool);

    /// @notice Mint a new token ID by depositing an underlying ERC20
    /// @param _underlying The address of the ERC20 token to deposit
    /// @param _amount The amount of the ERC20 token to deposit
    /// @return newId The newly created token ID
    function mint(address _underlying, uint256 _amount) external returns (uint256 newId);

    /// @notice Mint multiple token IDs for the same underlying ERC20
    /// @param _underlying The address of the ERC20 token to deposit
    /// @param _amount Array of amounts to deposit, one per new ID
    /// @return newId Array of newly created token IDs
    function mintMany(address _underlying, uint256[] calldata _amount) external returns (uint256[] memory newId);

    /// @notice Burn a token ID to redeem the underlying ERC20
    /// @param _id The token ID to burn
    /// @return redeemed The amount of underlying ERC20 released
    function burn(uint256 _id) external returns (uint256 redeemed);

    /// @notice Burn multiple token IDs in a single transaction
    /// @param _id Array of token IDs to burn
    /// @return redeemed The total amount of underlying ERC20 released
    function burnMany(uint256[] calldata _id) external returns (uint256 redeemed);

    /// @notice Merge multiple token IDs into a destination ID (all must share the same underlying)
    /// @param _id Array of token IDs to merge (must be distinct from _to)
    /// @param _to The destination token ID receiving the merged amounts
    /// @return Whether the merge succeeded
    function merge(uint256[] calldata _id, uint256 _to) external returns (bool);

    /// @notice Split a token ID into multiple new IDs with specified amounts
    /// @param _id The token ID to split
    /// @param splitAmount Array of amounts for each new ID (must sum to original amount)
    /// @return newId Array of newly created token IDs
    function split(uint256 _id, uint256[] calldata splitAmount) external returns (uint256[] memory newId);

    /// @notice Push (transfer) a token ID to another address
    /// @param _id The token ID to transfer
    /// @param _to The recipient address
    /// @return Whether the transfer succeeded
    function push(uint256 _id, address _to) external returns (bool);

    /// @notice Push (transfer) a token ID with a memo
    /// @param _id The token ID to transfer
    /// @param _to The recipient address
    /// @param _memo Optional data to attach to the transfer
    /// @return Whether the transfer succeeded
    function push(uint256 _id, address _to, bytes calldata _memo) external returns (bool);

    /// @notice Push multiple token IDs to corresponding addresses
    /// @param _id Array of token IDs to transfer
    /// @param _to Array of recipient addresses (one per ID)
    /// @return Whether the transfer succeeded
    function pushMany(uint256[] calldata _id, address[] calldata _to) external returns (bool);

    /// @notice Push multiple token IDs with individual memos
    /// @param _id Array of token IDs to transfer
    /// @param _to Array of recipient addresses
    /// @param _memo Array of memos (one per transfer)
    /// @return Whether the transfers succeeded
    function pushMany(uint256[] calldata _id, address[] calldata _to, bytes[] calldata _memo) external returns (bool);

    /// @notice Pull (claim) a token ID from its owner (requires approval or operator status)
    /// @param _id The token ID to claim
    /// @param _to The recipient address
    /// @param _memo Optional data to attach to the transfer
    /// @return Whether the claim succeeded
    function pull(uint256 _id, address _to, bytes calldata _memo) external returns (bool);

    /// @notice Pull multiple token IDs in a single transaction
    /// @param _id Array of token IDs to claim
    /// @param _to Array of recipient addresses
    /// @param _memo Array of memos (one per claim)
    /// @return Whether the claims succeeded
    function pullMany(uint256[] calldata _id, address[] calldata _to, bytes[] calldata _memo) external returns (bool);

    /// @notice Approve or revoke approval for a spender on a specific token ID
    /// @param _spender The address to set approval for
    /// @param _id The token ID to grant access to
    /// @param _approve Whether to grant or revoke approval
    /// @return Whether the operation succeeded
    function setApproval(address _spender, uint256 _id, bool _approve) external returns (bool);

    /// @notice Set or revoke operator status (allows operator to pull any of the caller's tokens)
    /// @param _spender The address to set as operator
    /// @param _approve Whether to grant or revoke operator status
    /// @return Whether the operation succeeded
    function setOperator(address _spender, bool _approve) external returns (bool);
}
