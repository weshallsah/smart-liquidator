// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProtocolRegistry
 * @notice Registry of all valid adaptor contracts that the YieldRouter
 *         is allowed to use for moving vault funds into protocols.
 *
 *         Only the contract owner can add/remove adaptors. This protects
 *         the system from malicious adaptors or rogue protocol integrations.
 *
 *         YieldRouter checks registry.isAdaptor[addr] before executing
 *         any MOVE_FUNDS action from the TEE + Relayer.
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ProtocolRegistry is Ownable {
    /// @notice adaptor address => approved or not
    mapping(address => bool) public isAdaptor;

    /// @notice list of all adaptors ever added
    address[] public adaptors;

    event AdaptorAdded(address adaptor);
    event AdaptorRemoved(address adaptor);

    /**
     * @notice Add a new adaptor to the registry
     * @param adaptor address of the adaptor contract
     */
    function addAdaptor(address adaptor) external onlyOwner {
        require(adaptor != address(0), "Registry: zero address");
        require(!isAdaptor[adaptor], "Registry: already added");

        isAdaptor[adaptor] = true;
        adaptors.push(adaptor);

        emit AdaptorAdded(adaptor);
    }

    /**
     * @notice Remove an adaptor from the registry
     * @dev Removes from mapping and array. Array removal is O(n), but registry updates are rare.
     * @param adaptor adaptor address to remove
     */
    function removeAdaptor(address adaptor) external onlyOwner {
        require(isAdaptor[adaptor], "Registry: not found");

        isAdaptor[adaptor] = false;

        // Remove from array
        uint256 len = adaptors.length;
        for (uint256 i = 0; i < len; i++) {
            if (adaptors[i] == adaptor) {
                adaptors[i] = adaptors[len - 1];
                adaptors.pop();
                break;
            }
        }

        emit AdaptorRemoved(adaptor);
    }

    /**
     * @notice returns all adaptor addresses registered
     */
    function getAdaptors() external view returns (address[] memory) {
        return adaptors;
    }
}
