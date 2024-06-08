// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {IERC1155TL} from "tl-creator-contracts/erc-1155/IERC1155TL.sol";

/// @title ERC1155TLMetadataElection.sol
/// @notice Contract to allow people to vote for which metadata to display on an ERC1155TL token
/// @author transientlabs.xyz
contract ERC1155TLMetadataElection is Ownable, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    struct MetadataOption {
        uint256 votes;
        string uri;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC1155TL public immutable nftContract;
    uint256 public immutable tokenId;
    MetadataOption[] public _metadataOptions;
    uint256 public leadingOptionIndex;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event NewLeader(uint256 indexed optionIndex);


    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address initOwner, address nftAddress, uint256 nftTokenId) Ownable(initOwner) ReentrancyGuard() {
        nftContract = IERC1155TL(nftAddress);
        tokenId = nftTokenId;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Function to add metadata options
    /// @dev Only owner
    /// @dev The very first option added should match what was minted
    /// @param uris The uris to add to the metadata options array
    function addMetadataOptions(string[] calldata uris) external onlyOwner {
        for (uint256 i = 0; i < uris.length; ++i) {
            MetadataOption memory option = MetadataOption({
                votes: 0,
                uri: uris[i]
            });
            _metadataOptions.push(option);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VOTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Function to vote for a metadata option
    /// @dev Applies reentrancy guard to make people vote with individual transactions
    /// @param optionIndex The index in the option array
    function vote(uint256 optionIndex) external nonReentrant {
        MetadataOption storage metadataOption = _metadataOptions[optionIndex];
        MetadataOption memory leadingMetadatOption = _metadataOptions[leadingOptionIndex];

        uint256 votes = ++metadataOption.votes;
        if (optionIndex != leadingOptionIndex &&  votes > leadingMetadatOption.votes) {
            leadingOptionIndex = optionIndex;
            nftContract.setTokenUri(tokenId, metadataOption.uri);
            emit NewLeader(optionIndex);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all the metadata options
    function getMetadataOptions() external view returns (MetadataOption[] memory) {
        return _metadataOptions;
    }
}