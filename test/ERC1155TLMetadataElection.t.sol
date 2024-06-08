// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {ERC1155TL} from "tl-creator-contracts/erc-1155/ERC1155TL.sol";
import {ERC1155TLMetadataElection, Ownable} from "src/ERC1155TLMetadataElection.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract ERC1155TLMetadataElectionTest is Test {

    using Strings for uint256;

    ERC1155TLMetadataElection public elec;
    ERC1155TL public nft;

    address beeple = makeAddr("beeple");
    address derp = makeAddr("derp");
    address blep = makeAddr("blep");
    address based = makeAddr("based");

    event NewLeader(uint256 indexed optionIndex);

    function setUp() public {
        address[] memory admins = new address[](0);

        // deploy nft contract
        nft = new ERC1155TL(false);
        nft.initialize("Test NFT", "NFT", "", address(this), 1000, address(this), admins, true, address(0));

        // create nft
        address[] memory addys = new address[](3);
        addys[0] = beeple;
        addys[1] = derp;
        addys[2] = blep;
        uint256[] memory amts = new uint256[](3);
        amts[0] = 69;
        amts[1] = 1;
        amts[2] = 420;
        nft.createToken("https://based.org/image1.jpg", addys, amts);

        // create election contract
        elec = new ERC1155TLMetadataElection(address(this), address(nft), 1);

        // approve election contract as admin
        admins = new address[](1);
        admins[0] = address(elec);
        nft.setRole(nft.ADMIN_ROLE(), admins, true);
    }

    function test_setUp() public view {
        assertEq(elec.owner(), address(this));
        assertEq(address(elec.nftContract()), address(nft));
        assertEq(elec.tokenId(), 1);
        assertEq(elec.leadingOptionIndex(), 0);
        assertEq(elec.getMetadataOptions().length, 0);
    }

    function test_addMetadataOptions_access(address hacker, uint256 numUris) public {
        vm.assume(hacker != address(this));
        if (numUris > 100) {
            numUris = numUris % 100;
        }

        string[] memory uris = new string[](numUris);
        for (uint256 i = 0; i < numUris; ++i) {
            uris[i] = i.toString();
        }
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        vm.prank(hacker);
        elec.addMetadataOptions(uris);
        assertEq(elec.getMetadataOptions().length, 0);

        elec.addMetadataOptions(uris);
        ERC1155TLMetadataElection.MetadataOption[] memory retrievedUris = elec.getMetadataOptions();
        assertEq(retrievedUris.length, numUris);
        for (uint256 i = 0; i < numUris; ++i) {
            assertEq(keccak256(bytes(uris[i])), keccak256(bytes(retrievedUris[i].uri)));
            assertEq(retrievedUris[i].votes, 0);
        }
    }

    function test_vote_onAll(uint256 numUris, address sender) public {
        if (numUris > 100) {
            numUris = numUris % 100;
        }
        
        // add uris
        string[] memory uris = new string[](numUris);
        for (uint256 i = 0; i < numUris; ++i) {
            uris[i] = i.toString();
        }
        elec.addMetadataOptions(uris);

        // vote on each one
        ERC1155TLMetadataElection.MetadataOption[] memory rOptions;
        for (uint256 i = 0; i < numUris; ++i) {
            vm.prank(sender);
            elec.vote(i);
            rOptions = elec.getMetadataOptions();
            assertEq(rOptions[i].votes, 1);
        }

        // vote on non-existent
        vm.expectRevert();
        vm.prank(sender);
            elec.vote(numUris + 1);
        
        // vote on each one again
        for (uint256 i = 0; i < numUris; ++i) {
            vm.prank(sender);
            elec.vote(i);
            rOptions = elec.getMetadataOptions();
            assertEq(rOptions[i].votes, 2);
        }
    }

    function test_vote_differentAddresses(address[] memory senders) public {
        vm.assume(senders.length > 0);

        string[] memory uris = new string[](1);
        uris[0] = "based";
        elec.addMetadataOptions(uris);

        for (uint256 i = 0; i < senders.length; ++i) {
            vm.prank(senders[i]);
            elec.vote(0);
            assertEq(elec.getMetadataOptions()[0].votes, i + 1);
        }
    }
    
    function test_vote() public {
        string[] memory uris = new string[](4);
        uris[0] = "https://based.org/image1.jpg";
        uris[1] = "https://based.org/image2.jpg";
        uris[2] = "https://based.org/image3.jpg";
        uris[3] = "https://based.org/image4.jpg";
        elec.addMetadataOptions(uris);

        ERC1155TLMetadataElection.MetadataOption[] memory rOptions;
        
        // beeple votes on the first option, which should match what is minted
        vm.prank(beeple);
        elec.vote(0);

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[0].votes, 1);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[0])));

        // derp votes on the second index twice, leading to a new leader
        vm.startPrank(derp);
        elec.vote(1);
        vm.expectEmit(true, true, true, true);
        emit NewLeader(1);
        elec.vote(1);
        vm.stopPrank();

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[1].votes, 2);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[1])));

        // blep votes on the third index
        vm.prank(blep);
        elec.vote(2);

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[2].votes, 1);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[1]))); // still metadata index 1

        // based votes on the fourth index three times, leading to a new leader
        vm.startPrank(based);
        elec.vote(3);
        elec.vote(3);
        vm.expectEmit(true, true, true, true);
        emit NewLeader(3);
        elec.vote(3);
        vm.stopPrank();

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[3].votes, 3);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[3])));

        // beeple votes on the first option twice
        vm.startPrank(beeple);
        elec.vote(0);
        elec.vote(0);
        vm.stopPrank();

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[0].votes, 3);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[3]))); // still metadata index 3

        // beeple votes on the first option again, leading to a new leader
        vm.startPrank(beeple);
        vm.expectEmit(true, true, true, true);
        emit NewLeader(0);
        elec.vote(0);
        vm.stopPrank();

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[0].votes, 4);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[0])));

        // beeple votes on the first option again
        vm.prank(beeple);
        elec.vote(0);

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[0].votes, 5);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[0])));

        // derp votes on the first option
        vm.prank(derp);
        elec.vote(0);

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[0].votes, 6);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[0])));

        // blep votes on the fourth option 5 times, leading to a new leader
        vm.startPrank(blep);
        elec.vote(3);
        elec.vote(3);
        elec.vote(3);
        vm.expectEmit(true, true, true, true);
        emit NewLeader(3);
        elec.vote(3);
        elec.vote(3);
        vm.stopPrank();

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[3].votes, 8);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[3])));

        // based votes on the third option 9 times, leading to a new leader
        vm.startPrank(based);
        elec.vote(2);
        elec.vote(2);
        elec.vote(2);
        elec.vote(2);
        elec.vote(2);
        elec.vote(2);
        elec.vote(2);
        vm.expectEmit(true, true, true, true);
        emit NewLeader(2);
        elec.vote(2);
        elec.vote(2);
        vm.stopPrank();

        rOptions = elec.getMetadataOptions();
        assertEq(rOptions[2].votes, 10);
        assertEq(keccak256(bytes(nft.uri(1))), keccak256(bytes(uris[2])));

    }

}