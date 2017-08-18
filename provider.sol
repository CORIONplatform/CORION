/*
    provider.sol
*/
pragma solidity ^0.4.15;

import "./module.sol";
import "./moduleHandler.sol";
import "./safeMath.sol";
import "./announcementTypes.sol";
import "./owned.sol";
import "./providerDB.sol";

contract provider is module, safeMath, providerCommonVars {
    /* Module functions */
    function replaceModule(address addr) onlyForModuleHandler external returns (bool success) {
        require( db.replaceOwner(addr) );
        super._replaceModule(addr);
        return true;
    }
    function transferEvent(address from, address to, uint256 value) onlyForModuleHandler external returns (bool success) {
        /*
            Transaction completed. This function is ony available for the modulehandler.
            It should be checked if the sender or the acceptor does not connect to the provider or it is not a provider itself if so than the change should be recorded.
            
            @from       From whom?
            @to         For who?
            @value      amount
            @bool       Was the function successful?
        */
        appendSupplyChanges(from, supplyChangeType_e.transferFrom, value);
        appendSupplyChanges(to, supplyChangeType_e.transferTo, value);
        return true;
    }
    function newSchellingRoundEvent(uint256 roundID, uint256 reward) onlyForModuleHandler external returns (bool success) {
        /*
            New schelling round. This function is only available for the moduleHandler.
            We are recording the new schelling round and we are storing the whole current quantity of the tokens.
            We generate a reward quantity of tokens directed to the providers address. The collected interest will be tranfered from this contract.
            
            @roundID        Number of the schelling round.
            @reward         token emission 
            @bool           Was the function successful?
        */
        //get current schelling round supply
        var ( _success, _mint ) = db.newSchellingRound(roundID, reward);
        require( _success );
        if ( _mint ) {
            require( moduleHandler(moduleHandlerAddress).mint(address(this), reward) );
        }
        return true;
    }
    function configureModule(announcementType aType, uint256 value, address addr) onlyForModuleHandler external returns(bool success) {
        if      ( aType == announcementType.providerPublicFunds )          { minFundsForPublic = value; }
        else if ( aType == announcementType.providerPrivateFunds )         { minFundsForPrivate = value; }
        else if ( aType == announcementType.providerPrivateClientLimit )   { privateProviderLimit = value; }
        else if ( aType == announcementType.providerPublicMinRate )        { publicMinRate = uint8(value); }
        else if ( aType == announcementType.providerPublicMaxRate )        { publicMaxRate = uint8(value); }
        else if ( aType == announcementType.providerPrivateMinRate )       { privateMinRate = uint8(value); }
        else if ( aType == announcementType.providerPrivateMaxRate )       { privateMaxRate = uint8(value); }
        else if ( aType == announcementType.providerGasProtect )           { gasProtectMaxRounds = value; }
        else if ( aType == announcementType.providerInterestMinFunds )     { interestMinFunds = value; }
        else if ( aType == announcementType.providerRentRate )             { rentRate = uint8(value); }
        else { return false; }
        super._configureModule(aType, value, addr);
        return true;
    }
    /* Provider database calls */
    // client
    function _isClientPaidUp(address clientAddress) constant returns(bool paid) {
        var (_success, _paid) = db.isClientPaidUp(clientAddress);
        require( _success );
        return _paid;
    }
    function _getClientSupply(address clientAddress) internal returns(uint256 amount) {
        var ( _success, _amount ) = db.getClientSupply(clientAddress);
        require( _success );
        return _amount;
    }
    function _getClientSupply(address clientAddress, uint256 schellingRound) internal returns(uint256 amount, bool valid) {
        var ( _success, _amount, _valid ) = db.getClientSupply(clientAddress, schellingRound);
        require( _success );
        return ( _amount, _valid );
    }
    function _getClientSupply(address clientAddress, uint256 schellingRound, uint256 oldAmount) internal returns(uint256 amount) {
        var ( _success, _amount, _valid ) = db.getClientSupply(clientAddress, schellingRound);
        require( _success );
        if ( _valid ) {
            return _amount;
        }
        return oldAmount;
    }
    function _getClientProviderUID(address clientAddress) internal returns(uint256 providerUID) {
        var ( _success, _providerUID ) = db.getClientProviderUID(clientAddress);
        require( _success );
        return _providerUID;
    }
    function _getClientLastPaidRate(address clientAddress) internal returns(uint8 rate) {
        var ( _success, _rate ) = db.getClientLastPaidRate(clientAddress);
        require( _success );
        return _rate;
    }
    function _joinToProvider(uint256 providerUID, address clientAddress) internal {
        var _success = db.joinToProvider(providerUID, clientAddress);
        require( _success );
    }
    function _partFromProvider(uint256 providerUID, address clientAddress) internal {
        var _success = db.partFromProvider(providerUID, clientAddress);
        require( _success );
    }
    function _checkForJoin(uint256 providerUID, address clientAddress, uint256 countLimitforPrivate) internal returns(bool allowed) {
        var ( _success, _allowed ) = db.checkForJoin(providerUID, clientAddress, countLimitforPrivate);
        require( _success );
        return _allowed;
    }
    function _getSenderStatus(uint256 providerUID) internal returns(senderStatus_e status) {
        var ( _success, _status ) = db.getSenderStatus(msg.sender, providerUID);
        require( _success );
        return _status;
    }
    function _getClientPaidUpTo(address clientAddress) internal returns(uint256 paidUpTo) {
        var ( _success, _paidUpTo ) = db.getClientPaidUpTo(clientAddress);
        require( _success );
        return _paidUpTo;
    }
    function _setClientPaidUpTo(address clientAddress, uint256 paidUpTo) internal {
        var ( _success ) = db.setClientPaidUpTo(clientAddress, paidUpTo);
        require( _success );
    }
    function _setClientLastPaidRate(address clientAddress, uint8 lastPaidRate) internal {
        var ( _success ) = db.setClientLastPaidRate(clientAddress, lastPaidRate);
        require( _success );
    }
    function _setClientSupply(address clientAddress, uint256 roundID, uint256 amount) internal {
        var ( _success ) = db.setClientSupply(clientAddress, roundID, amount);
        require( _success );
    }
    function _setClientSupply(address clientAddress, uint256 amount) internal {
        var ( _success ) = db.setClientSupply(clientAddress, amount);
        require( _success );
    }
    //provider
    function _openProvider(bool priv, string name, string website, uint256 country, string info, uint8 rate, bool isForRent, address admin) internal returns(uint256 newUID) {
        var (_success, _newUID) = db.openProvider(msg.sender, priv, name, website, country, info, rate, isForRent, admin);
        require( _success );
        return _newUID;
    }
    function _closeProvider(address owner) internal {
        var _success = db.closeProvider(owner);
        require( _success );
    }
    function _setProviderInfoFields(uint256 providerUID, string name, string website, 
        uint256 country, string info, address admin, uint8 rate) internal {
        var _success = db.setProviderInfoFields(providerUID, name, website, country, info, admin, rate);
        require( _success );
    }
    function _isProviderValid(uint256 providerUID) internal returns(bool valid) {
        var ( _success, _valid ) = db.isProviderValid(providerUID);
        require( _success );
        return _valid;
    }
    function _getProviderOwner(uint256 providerUID) internal returns(address owner) {
        var ( _success, _owner ) = db.getProviderOwner(providerUID);
        require( _success );
        return _owner;
    }
    function _getProviderClosed(uint256 providerUID) internal returns(uint256 closed) {
        var ( _success, _closed ) = db.getProviderClosed(providerUID);
        require( _success );
        return _closed;
    }
    function _getProviderAdmin(uint256 providerUID) internal returns(address admin) {
        var ( _success, _admin ) = db.getProviderAdmin(providerUID);
        require( _success );
        return _admin;
    }
    function _setProviderInvitedUser(uint256 providerUID, address clientAddress, bool status) internal {
        var _success = db.setProviderInvitedUser(providerUID, clientAddress, status);
        require( _success );
    }
    function _getProviderPriv(uint256 providerUID) internal returns(bool priv) {
        var ( _success, _priv ) = db.getProviderPriv(providerUID);
        require( _success );
        return _priv;
    }
    function _getProviderSupply(uint256 providerUID) internal returns(uint256 supply) {
        var ( _success, _supply ) = db.getProviderSupply(providerUID);
        require( _success );
        return _supply;
    }
    function _getProviderSupply(uint256 providerUID, uint256 schellingRound) internal returns(uint256 supply, bool valid) {
        var ( _success, _supply, _valid ) = db.getProviderSupply(providerUID, schellingRound);
        require( _success );
        return ( _supply, _valid );
    }
    function _getProviderSupply(uint256 providerUID, uint256 schellingRound, uint256 oldAmount) internal returns(uint256 supply) {
        var ( _success, _supply, _valid ) = db.getProviderSupply(providerUID, schellingRound);
        require( _success );
        if ( _valid ) {
            return _supply;
        }
        return oldAmount;
    }
    function _setProviderSupply(uint256 providerUID, uint256 amount) internal {
        var ( _success ) = db.setProviderSupply(providerUID, amount);
        require( _success );
    }
    function _setProviderSupply(uint256 providerUID, uint256 schellingRound, uint256 amount) internal {
        var ( _success ) = db.setProviderSupply(providerUID, schellingRound, amount);
        require( _success );
    }
    function _getProviderIsForRent(uint256 providerUID) internal returns(bool isForRent) {
        var ( _success, _isForRent ) = db.getProviderIsForRent(providerUID);
        require( _success );
        return _isForRent;
    }
    function _getProviderRateHistory(uint256 providerUID, uint256 schellingRound, uint8 oldRate) internal returns(uint8 rate) {
        var ( _success, _rate, _valid ) = db.getProviderRateHistory(providerUID, schellingRound);
        require( _success );
        if ( _valid ) {
            return _rate;
        } else {
            return oldRate;
        }
    }
    //schelling
    function _getCurrentSchellingRound() internal returns(uint256 roundID) {
        var ( _success, _roundID ) = db.getCurrentSchellingRound();
        require( _success );
        return _roundID;
    }
    function _getSchellingRoundDetails(uint256 roundID) internal returns(uint256 reward, uint256 supply) {
        var ( _success, _reward, _supply ) = db.getSchellingRoundDetails(roundID);
        require( _success );
        return ( _reward, _supply );
    }
    function _getSchellingRoundSupply() internal returns(uint256 supply) {
        var ( _success, _reward, _supply ) = db.getSchellingRoundDetails();
        require( _success );
        return _supply;
    }
    function _setSchellingRoundSupply(uint256 amount) internal {
        var ( _success ) = db.setSchellingRoundSupply(amount);
        require( _success );
    }
    /*function _setSchellingRoundReward(uint256 reward) internal {
        var ( _success ) = db.setSchellingRoundReward(reward);
        require( _success );
    }*/
    /* Enumerations */
    enum supplyChangeType_e {
        joinToProvider,
        partFromProvider,
        closeProvider,
        transferFrom,
        transferTo
    }
    /* Structures */
    struct checkReward_s {
        address owner;
        address admin;
        senderStatus_e senderStatus;
        uint256 roundID;
        uint256 roundTo;
        uint256 providerSupply;
        uint256 clientSupply;
        uint256 ownerSupply;
        uint256 schellingReward;
        uint256 schellingSupply;
        uint8   rate;
        bool    priv;
        bool    isForRent;
        uint256 closed;
        uint256 ownerPaidUpTo;
        uint256 clientPaidUpTo;
        bool getInterest;
        uint256 tmpReward;
        uint256 currentSchellingRound;
        uint256 senderReward;
        uint256 adminReward;
        uint256 ownerReward;
        bool setOwnerRate;
    }
    struct newProvider_s {
        uint256 balance;
        uint256 newUID;
    }
    /* Variables */
    uint256 public minFundsForPublic    = 3e9;
    uint256 public minFundsForPrivate   = 8e9;
    uint256 public privateProviderLimit = 250;
    uint8   public publicMinRate        = 30;
    uint8   public privateMinRate       = 0;
    uint8   public publicMaxRate        = 70;
    uint8   public privateMaxRate       = 100;
    uint256 public gasProtectMaxRounds  = 200;
    uint256 public interestMinFunds     = 25e9;
    uint8   public rentRate             = 20;
    providerDB public db;
    /* Constructor */
    function provider(bool forReplace, address moduleHandlerAddr, address dbAddr) module(moduleHandlerAddr) {
        /*
            Install function.
            
            @forReplace                 This address will be replaced with the old one or not.
            @moduleHandlerAddr          Modulhandler's address
            @dbAddr                     Address of database           
        */
        require( dbAddr != 0x00 );
        db = providerDB(dbAddr);
        if ( forReplace ) {
            require( db.replaceOwner(this) );
        }
    }
    /* Externals */
    function openProvider(bool priv, string name, string website, uint256 country, string info, uint8 rate, bool isForRent, address admin) readyModule external {
        /*
            Creating a provider.
            During the ICO its not allowed to create provider.
            To one address only one provider can belong to.
            Address, how is connected to the provider can not create a provider.
            For opening, has to have enough capital.
            All the functions of the provider except of the closing are going to be handled by the admin.
            The provider can be start as a rent as well, in this case the isForRent has to be true/correct.
            In case it runs as a rent the 20% of the profit will belong to the leser and the rest goes to the admin.
            
            @priv           Is private provider?
            @name           Provider’s name.
            @website        Provider’s website.
            @country        Provider’s country.
            @info           Provider’s short introduction.
            @rate           Rate of the emission what is going to be transfered to the client by the provider.
            @isForRent      Is for Rent or not?
            @admin          The admin's address.
        */
        newProvider_s memory _newProvider;
        _newProvider.balance = getTokenBalance(msg.sender);
        checkCorrectRate(priv, rate);
        require( admin != msg.sender );
        require( ( ! isForRent ) || ( isForRent && admin != 0x00) );
        require( _getClientProviderUID(msg.sender) == 0x00 );
        require( ( priv && ( _newProvider.balance >= minFundsForPrivate )) || ( ! priv && ( _newProvider.balance >= minFundsForPublic )) );
        _newProvider.newUID = _openProvider(priv, name, website, country, info, rate, isForRent, admin);
        _joinToProvider(_newProvider.newUID, msg.sender);
        if ( priv ) {
            appendSupplyChanges(msg.sender, supplyChangeType_e.joinToProvider, _newProvider.balance);
        }
        EProviderOpen(_newProvider.newUID);
    }
    function closeProvider() readyModule external {
        /*
            Closing and inactivate the provider.
            It is only possible to close that active provider which is owned by the sender itself after calling the whole share of the emission.
            Whom were connected to the provider those clients will have to disconnect after they’ve called their share of emission which was not called before.
        */
        var providerUID = _getClientProviderUID(msg.sender);
        require( providerUID > 0 );
        require( _getProviderOwner(providerUID) == msg.sender );
        require( _isClientPaidUp(msg.sender) );
        appendSupplyChanges(msg.sender, supplyChangeType_e.closeProvider, 0);
        _closeProvider(msg.sender);
        EProviderClose(providerUID);
    }
    function setProviderDetails(uint256 providerUID, string name, string website, uint256 country, string info, uint8 rate, address admin) readyModule external {
        /*
            Modifying the datas of the provider.
            This can only be invited by the provider’s admin.
            The emission rate is only valid for the next schelling round for this one it is not.
            The admin can only be changed by the address of the provider.
            
            @providerUID        Address of the provider.
            @name               Provider's name.
            @website            Website.
            @country            Country.
            @info               Short intro.
            @rate               Rate of the emission what will be given to the client.
            @admin              The new address of the admin. If we do not want to set it then we should enter 0x00. 
        */
        require( _isProviderValid(providerUID) );
        checkCorrectRate( _getProviderPriv(providerUID), rate);
        var _admin = _getProviderAdmin(providerUID);
        var _status = _getSenderStatus(providerUID);
        require( ( _status == senderStatus_e.owner && msg.sender != admin ) ||
            ( ( _status == senderStatus_e.admin || _status == senderStatus_e.adminAndClient ) && admin == _admin ) );
        _setProviderInfoFields(providerUID, name, website, country, info, admin, rate);
        EProviderNewDetails(providerUID);
    }
    function joinProvider(uint256 providerUID) readyModule external {
        /*
            Connection to the provider.
            Providers can not connect to other providers.
            If is a client at any provider, then it is not possible to connect to other provider one.
            It is only possible to connect to valid and active providers.
            If is an active provider then the client can only connect, if address is permited at the provider (Whitelist).
            At private providers, the number of the client is restricted. If it reaches the limit no further clients are allowed to connect.
            This process has a transaction fee based on the senders whole token quantity.
            
            @providerUID        Provider Unique ID
        */
        require( _checkForJoin(providerUID, msg.sender, privateProviderLimit) );
        var _supply = getTokenBalance(msg.sender);
        // We charge fee
        require( moduleHandler(moduleHandlerAddress).processTransactionFee(msg.sender, _supply) );
        _supply = getTokenBalance(msg.sender);
        _joinToProvider(providerUID, msg.sender);
        appendSupplyChanges(msg.sender, supplyChangeType_e.joinToProvider, _supply);
        EJoinProvider(providerUID, msg.sender);
    }
    function partProvider() readyModule external {
        /*
            Disconnecting from the provider.
            Before disconnecting we should poll our share from the token emission even if there was nothing factually.
            It is only possible to disconnect those providers who were connected by us before.
        */
        var providerUID = _getClientProviderUID(msg.sender);
        require( providerUID > 0 );
        require( _getProviderOwner(providerUID) != msg.sender );
        // Is paid up?
        require( _isClientPaidUp(msg.sender) );
        var _supply = getTokenBalance(msg.sender);
        // ONLY IF THE PROVIDER ARE OPEN
        if ( _getProviderClosed(providerUID) == 0 ) {
            appendSupplyChanges(msg.sender, supplyChangeType_e.partFromProvider, _supply);
        }
        _partFromProvider(providerUID, msg.sender);
        EPartProvider(providerUID, msg.sender);
    }
    function getReward(address beneficiary, uint256 providerUID, uint256 roundLimit) readyModule external {
        /*
            Polling the share from the token emission token emission for clients and for providers.

            It is optionaly possible to give an address of a beneficiary for whom we can transfer the accumulated amount. In case we don’t enter any address then the amount will be transfered to the caller’s address.
            As the interest should be checked at each schelling round in order to get the share from that so to avoid the overflow of the gas the number of the check rounds should be limited.
            It is possible to enter optionaly the number of the check rounds.  If it is 0 then it is automatic.
            
            @beneficiary        Address of the beneficiary
            @limit              Quota of the check rounds.
            @providerUID        Unique ID of the provider
            @reward             Accumulated amount from the previous rounds.
        */
        var _roundLimit = roundLimit;
        var _beneficiary = beneficiary;
        if ( _roundLimit == 0 ) { _roundLimit = gasProtectMaxRounds; }
        if ( _beneficiary == 0x00 ) { _beneficiary = msg.sender; }
        var (_data, _round) = checkReward(msg.sender, providerUID, _roundLimit);
        require( _round > 0 );
        if ( msg.sender == _data.admin && _data.adminReward > 0) {
            require( moduleHandler(moduleHandlerAddress).transfer(address(this), _beneficiary, safeAdd(_data.senderReward, _data.adminReward), false ) );
        } else {
            if ( _data.senderReward > 0 )  {
                require( moduleHandler(moduleHandlerAddress).transfer(address(this), _beneficiary, _data.senderReward, false ) );
            }
            if ( _data.adminReward > 0 )  {
                require( moduleHandler(moduleHandlerAddress).transfer(address(this), _data.admin, _data.adminReward, false ) );
            }
        }
        if ( _data.ownerReward > 0 ) {
            require( moduleHandler(moduleHandlerAddress).transfer(address(this), _data.owner, _data.ownerReward, false ) );
        }
    }
    function manageInvitations(uint256 providerUID, address[] invite, address[] revokeInvite) readyModule external {
        /*
            Permition of the user to be able to connect to the provider.
            This can only be invited by the provider's owner or admin.
            With this kind of call only 100 address can be permited. 
            
            @providerUID            Provider Unique ID
            @invite                 Array of the addresses for whom the connection is allowed.
            @revokeInvite           Array of the addresses for whom the connection is disallowed.
        */
        uint256 a;
        require( invite.length <= 100 && revokeInvite.length <= 100 );
        require( _isProviderValid(providerUID) );
        var _status = _getSenderStatus(providerUID);
        require( _status == senderStatus_e.owner || 
            _status == senderStatus_e.admin || 
            _status == senderStatus_e.adminAndClient );
        for ( a=0 ; a<invite.length ; a++ ) {
            _setProviderInvitedUser(providerUID, invite[a], true);
            EInviteStatus(providerUID, invite[a], true);
        }
        for ( a=0 ; a<revokeInvite.length ; a++ ) {
            _setProviderInvitedUser(providerUID, revokeInvite[a], false);
            EInviteStatus(providerUID, revokeInvite[a], true);
        }
    }
    /* Internals */
    function checkReward(address client, uint256 providerUID, uint256 roundLimit) internal returns(checkReward_s data, uint256 round) {
        if ( providerUID == 0) {
            return;
        }
        var senderStatus = _getSenderStatus(providerUID);
        if ( senderStatus == senderStatus_e.none ) {
            return;
        }
        data.owner = _getProviderOwner(providerUID);
        data.admin = _getProviderAdmin(providerUID);
        data.priv = _getProviderPriv(providerUID);
        data.isForRent = _getProviderIsForRent(providerUID);

        // Get paidUps and set the first schelling round ID
        data.clientPaidUpTo = _getClientPaidUpTo(client);
        data.roundID = data.clientPaidUpTo;
        if ( senderStatus != senderStatus_e.client) {
            data.ownerPaidUpTo = _getClientPaidUpTo(data.owner);
            if ( senderStatus == senderStatus_e.adminAndClient && data.clientPaidUpTo < data.ownerPaidUpTo ) {
                data.roundID = data.clientPaidUpTo;
            } else {
                data.roundID = data.ownerPaidUpTo;
            }
        }
        data.currentSchellingRound = _getCurrentSchellingRound();
        data.roundTo = data.currentSchellingRound;
        data.closed = _getProviderClosed(providerUID);
        if ( data.closed > 0 ) {
            data.roundTo = data.closed;
        }
        
        // load last rate
        if ( senderStatus == senderStatus_e.admin ) {
            data.rate = _getClientLastPaidRate(data.owner);
        } else {
            data.rate = _getClientLastPaidRate(client);
        }
        
        // For loop START
        for ( data.roundID ; data.roundID<data.roundTo ; data.roundID++ ) {
            if ( roundLimit > 0 && round == roundLimit ) { break; }
            round = safeAdd(round, 1);
            // Get provider Rate
            data.rate = _getProviderRateHistory(providerUID, data.roundID, data.rate);
            // Get schelling reward and supply for the current checking round
            (data.schellingReward, data.schellingSupply) = _getSchellingRoundDetails(data.roundID);
            // Get provider supply for the current checking round
            data.providerSupply = _getProviderSupply(providerUID, data.roundID, data.providerSupply);
            // Get client/owner supply for this checking round
            if ( data.clientPaidUpTo > 0 ) {
                data.clientSupply = _getClientSupply(client, data.roundID, data.clientSupply);
            }
            if ( data.ownerPaidUpTo > 0 ) {
                data.ownerSupply = _getClientSupply(data.owner, data.roundID, data.ownerSupply);
            }
            // Check, that the Provider has right for getting interest for the current checking round
            data.getInterest = ( ! data.priv ) || ( data.priv && interestMinFunds <= data.providerSupply );
            if ( data.getInterest ) {
            } else {
            }
            // Checking client reward if he is the sender
            if ( ( senderStatus == senderStatus_e.client || senderStatus == senderStatus_e.adminAndClient ) && data.clientPaidUpTo <= data.roundID ) {
                // Check for schelling reward, rate (we can not mul with zero) and if the provider get interest or not
                if ( data.schellingReward > 0 && data.schellingSupply > 0 && data.rate > 0 && data.getInterest ) {
                    data.senderReward = safeAdd(data.senderReward, safeMul(safeMul(data.schellingReward, data.clientSupply) / data.schellingSupply, data.rate) / 100);
                }
                if ( data.clientPaidUpTo <= data.roundID ) {
                    data.clientPaidUpTo = safeAdd(data.roundID, 1);
                }
            }
            // After closing an provider muss be checked all round. If then is closed we should not check again.
            if ( data.closed == 0 && senderStatus != senderStatus_e.client ) {
                if ( data.ownerPaidUpTo <= data.roundID && data.getInterest ) {
                    // Checking owners reward if he is the sender or was the admin on isForRent
                    if ( data.priv ) {
                        // PaidUpTo check, need be priv and the calles is not client
                        // Check for schelling reward
                        if ( data.schellingReward > 0 && data.schellingSupply > 0 ) {
                            // If the provider isForRent, then the admin can calculate owner's reward, but we send that for the owner
                            // If the provider is not for rent, then the admin can receive owners reward
                            data.tmpReward = safeMul(data.schellingReward, data.ownerSupply) / data.schellingSupply;
                            if ( data.isForRent && senderStatus != senderStatus_e.owner) {
                                data.ownerReward = safeAdd(data.ownerReward, data.tmpReward);
                            } else {
                                data.senderReward = safeAdd(data.senderReward, data.tmpReward);
                            }
                        }
                    }
                    // Checking revenue from the clients if the caller was the owner or admin
                    // Check for schelling reward, rate (we can not mul with zero)
                    if ( data.schellingReward > 0 && data.schellingSupply > 0 && data.rate < 100 ) {
                        // calculating into temp variable
                        if ( data.priv ) {
                            data.tmpReward = safeSub(data.providerSupply, data.ownerSupply);
                        } else {
                            data.tmpReward = data.providerSupply;
                        }
                        if ( data.tmpReward > 0 ) {
                            data.tmpReward = safeMul(safeMul(data.schellingReward, data.tmpReward) / data.schellingSupply, safeSub(100, data.rate)) / 100;
                            // if the provider isForRent, then the reward will be disturbed
                            if ( data.isForRent ) {
                                if ( senderStatus == senderStatus_e.owner ) {
                                    data.senderReward = safeAdd(data.senderReward, safeMul(data.tmpReward, rentRate) / 100);
                                } else {
                                    data.ownerReward = safeAdd(data.ownerReward, safeMul(data.tmpReward, rentRate) / 100);
                                }
                                data.adminReward = safeAdd(data.adminReward, safeSub(data.tmpReward, safeMul(data.tmpReward, rentRate) / 100));
                            } else {
                                // if not and the calles is the owner he got everything.
                                if ( senderStatus == senderStatus_e.owner ) {
                                    data.senderReward = safeAdd(data.senderReward, data.tmpReward);
                                } else {
                                    data.adminReward = safeAdd(data.adminReward, data.tmpReward);
                                }
                            }
                        }
                    }
                }
                if ( data.ownerPaidUpTo <= data.roundID ) {
                    data.ownerPaidUpTo = safeAdd(data.roundID, 1);
                }
                // If the owner call
                if ( data.clientPaidUpTo <= data.roundID ) {
                    data.clientPaidUpTo = safeAdd(data.roundID, 1);
                }
            }
        }
        // For loop END
        
        // Set last paidUpTo, rate and supply
        if ( senderStatus != senderStatus_e.admin ) {
            if ( client != data.owner || ( client == data.owner && data.priv ) ) {
                _setClientSupply(client, data.clientPaidUpTo, data.clientSupply);
            }
            _setClientPaidUpTo(client, data.clientPaidUpTo);
            _setClientLastPaidRate(client, data.rate);
        }
        if ( senderStatus != senderStatus_e.client ) {
            if ( data.priv ) {
                _setClientSupply(data.owner, data.ownerPaidUpTo, data.ownerSupply);
            }
            _setClientPaidUpTo(data.owner, data.ownerPaidUpTo);
            _setClientLastPaidRate(data.owner, data.rate);
        }
        //save last provider supply
        _setProviderSupply(providerUID, data.roundID, data.providerSupply);
    }
    function appendSupplyChanges(address client, supplyChangeType_e supplyChangeType, uint256 amount) internal {
        uint256 _clientSupply;
        var providerUID = _getClientProviderUID(client);
        if ( providerUID == 0 || _getProviderClosed(providerUID) > 0) { return; }
        var _priv = _getProviderPriv(providerUID);
        var _owner = _getProviderOwner(providerUID);
        // The public provider owners supply are not calculated in the provider supply, but we need set the last supply ID's
        if ( _owner != client || ( _owner == client && _priv ) || supplyChangeType == supplyChangeType_e.closeProvider ) {
            var _providerSupply = _getProviderSupply(providerUID);
            
            uint256 _providerSupplyNew;
            if ( supplyChangeType == supplyChangeType_e.joinToProvider || supplyChangeType == supplyChangeType_e.transferTo ) {
                _providerSupplyNew = safeAdd(_providerSupply, amount);
            } else if ( supplyChangeType == supplyChangeType_e.transferFrom || supplyChangeType == supplyChangeType_e.partFromProvider ) {
                _providerSupplyNew = safeSub(_providerSupply, amount);
            }
            if ( supplyChangeType != supplyChangeType_e.closeProvider ) { 
                _setProviderSupply(providerUID, _providerSupplyNew);
            }
            
            var _schellingSupply = _getSchellingRoundSupply();
            // check if the provider used to get interest - if so, remove it from the schelling supply
            if (checkForInterest(_providerSupply, _priv)) {
                _schellingSupply = safeSub(_schellingSupply, _providerSupply);
            }
            // check if the provider should get interest now
            if (checkForInterest(_providerSupplyNew, _priv)) {
                _schellingSupply = safeAdd(_schellingSupply, _providerSupplyNew);
            }
            _setSchellingRoundSupply(_schellingSupply);
        }
        // Client supply changes
        _clientSupply = getTokenBalance(client);
        if ( supplyChangeType != supplyChangeType_e.closeProvider && ( client != _owner || ( client == _owner && _priv ) ) ) {
            _setClientSupply(client, _clientSupply);
        }
        // check owner balance for the provider limits
        if ( supplyChangeType == supplyChangeType_e.transferFrom && client == _owner ) {
            require( ( _priv && _clientSupply >= minFundsForPrivate ) ||( ( ! _priv ) && _clientSupply >= minFundsForPublic ));
        }
    }
    function checkForInterest(uint256 supply, bool priv) internal returns (bool) {
        return ( ! priv && supply > 0) || ( priv && interestMinFunds <= supply );
    }
    function checkCorrectRate(bool priv, uint8 rate) internal {
        /*
            Inner function which checks if the amount of interest what is given by the provider is fits to the criteria.
            
            @priv       Is the provider private or not?
            @rate       Percentage/rate of the interest
        */
        require(( ! priv && ( rate >= publicMinRate && rate <= publicMaxRate ) ) || 
                ( priv && ( rate >= privateMinRate && rate <= privateMaxRate ) ) );
    }
    function getTokenBalance(address addr) internal returns (uint256 balance) {
        /*
            Inner function in order to poll the token balance of the address.
            
            @addr       Address
            
            @balance    Balance of the address.
        */
        var (_success, _balance) = moduleHandler(moduleHandlerAddress).balanceOf(addr);
        require( _success );
        return _balance;
    }
    /* Constants */
    function checkReward(uint256 providerUID, uint256 roundLimit) public constant returns (uint256 senderReward, uint256 adminReward, uint256 ownerReward, uint256 round) {
        /*
            Polling the share from the token emission token emission for clients and for providers.

            It is optionaly possible to give an address of a beneficiary for whom we can transfer the accumulated amount. In case we don’t enter any address then the amount will be transfered to the caller’s address.
            As the interest should be checked at each schelling round in order to get the share from that so to avoid the overflow of the gas the number of the check rounds should be limited.
            It is possible to enter optionaly the number of the check rounds.  If it is 0 then it is automatic.
            
            @beneficiary        Address of the beneficiary
            @limit              Quota of the check rounds.
            @providerUID        Unique ID of the provider
            @reward             Accumulated amount from the previous rounds.
        */
        var _roundLimit = roundLimit;
        if ( _roundLimit == 0 ) { _roundLimit = _roundLimit-1; } // willfully
        var (_data, _round) = checkReward(msg.sender, providerUID, _roundLimit);
        return (_data.senderReward, _data.adminReward, _data.ownerReward, _round);
    }
    /* Events */
    event EProviderOpen(uint256 UID);
    event EProviderClose(uint256 UID);
    event EProviderNewDetails(uint256 UID);
    event EJoinProvider(uint256 UID, address clientAddress);
    event EPartProvider(uint256 UID, address clientAddress);
    event EInviteStatus(uint256 UID, address clientAddress, bool status);
}
