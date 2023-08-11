// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;



contract DecentralizedNews {
    mapping(bytes32 => address) articleCreator; //Creator of Article
    mapping(address => bool) isApproved; //User allowed to publish article
    

    bytes32[] public pendingArticles;
    //save approved articles in Events;

    event articleApproved(bytes32);

    function createArticle(bytes32 _hash) public {
        require(isApproved[msg.sender], "User not allowed to create Articles");
       
        articleCreator[_hash] = msg.sender;
        

    }
}
