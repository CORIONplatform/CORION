pragma solidity ^0.4.11;

contract owned {
    address private owner = msg.sender;
    
    function replaceOwner(address newOwner) external returns(bool) {
        /*
            Owner replace.
            
            @newOwner   Address of new owner.
        */
        require( isOwner() );
        owner = newOwner;
        return true;
    }
    
    function isOwner() internal returns(bool) {
        /*
            Check of owner address.
            
            @bool   Owner has called the contract or not 
        */
        return owner == msg.sender;
    }
}


contract ownedDB {
    address private owner;
    
    function replaceOwner(address newOwner) external returns(bool) {
        /*
            Owner replace.
            
            @newOwner   Address of new owner.
        */
        require( isOwner() );
        owner = newOwner;
        return true;
    }
    
    function isOwner() internal returns(bool) {
        /*
            Check of owner address.
            
            @bool   Owner has called the contract or not 
        */
        if ( owner == 0x00 ) {
            return true;
        }
        return owner == msg.sender;
    }
}
