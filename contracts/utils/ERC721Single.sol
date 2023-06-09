// SPDX-License-Identifier: MIT
// Based on OpenZeppelin ERC721 implementation
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension. Optimized for handling only one token.
 */
contract ERC721Single is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    uint256 constant internal TOKEN_ID = 1;

    /**
     * @notice The token collection name.
     */
    string public name;

    /**
     * @notice The token collection symbol.
     */
    string public symbol;

    // Owner of the unique token
    address private _owner;

    // Aapproved address for the unique token
    address private _approved;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    string private _tokenURI;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory _name, string memory _symbol, string memory uri) {
        name = _name;
        symbol = _symbol;
        _tokenURI = uri;
        _owner = address(this);
        emit Transfer(address(0), address(this), TOKEN_ID);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Retrieves the number of tokens in input account.
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return owner == _owner ? 1 : 0;
    }

    /**
     * @notice Retrieves the owner of input token id.
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);
        return _owner;
    }

    /**
     * @notice Retrieves the metadata URI for input token id.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return _tokenURI;
    }

    /**
     * @notice Gives permission to transfer a token to an account.
     * @dev See {IERC721-approve}.
     * @param to Account to give permission
     * @param tokenId Id of the token that `to` is allowed to transfer
     */
    function approve(address to, uint256 tokenId) public virtual override {
        _requireMinted(tokenId);
        require(to != _owner, "ERC721: approval to current owner");

        require(
            _msgSender() == _owner || isApprovedForAll(_owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );
        _approved = to;
        emit Approval(_owner, to, tokenId);
    }

    /**
     * @notice Retrieves the account approved for input token id.
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);
        return _approved;
    }

    /**
     * @notice Approve or remove an account as an operator for the caller.
     * @dev Operators can call {IERC721-transferFrom} or {IERC721-safeTransferFrom}
     * for any token owned by the caller. See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC721: approve to caller");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @notice Checks if an operator is allowed to manage all of the assets of an account.
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @notice Transfers a token from an account to an other.
     * @dev The caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    /**
     * @notice Safely transfers a token from an account to an other.
     * @dev If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received},
     * which is called upon a safe transfer. See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @notice Safely transfers a token from an account to an other.
     * @dev If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received},
     * which is called upon a safe transfer. See {IERC721-safeTransferFrom}.
     * @param from The current owner of the NFT
     * @param to The new owner
     * @param tokenId The NFT to transfer
     * @param data Additional data with no specified format, sent in call to `to`
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        _requireMinted(tokenId);
        return (spender == _owner || isApprovedForAll(_owner, spender) || _approved == spender);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        _requireMinted(tokenId);
        require(_owner == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        delete _approved;

        _owner = to;
        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` from `from` to `to`. If `to` is a contract,
     *  it must implement {IERC721Receiver-onERC721Received}.
     *
     *  As opposed to {safeTransferFrom}, this imposes no restrictions on msg.sender.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _setTokenURI(string memory uri) internal {
        _tokenURI = uri;
    }

    /**
     * @dev Reverts if the `tokenId` is not the unique token id.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(tokenId == TOKEN_ID, "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
