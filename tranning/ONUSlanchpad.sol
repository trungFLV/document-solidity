//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ONUSLaunchpad is AccessControlEnumerable, ReentrancyGuard {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    /// @dev Only TRANSFER_ROLE holders can have tokens transferred from or to them, during restricted transfers.
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    /// @dev The next project ID.
    uint256 public nextProjectId;

    struct Project {
        ERC20 saleToken;
        ERC20 stakedToken;
        ERC20 currencyToken;
        uint256 totalSaleToken;
        uint256 pricePerSaleToken;
        uint256 maxCurrencyPerUser;
        uint256 minCurrencyPerUser;
        uint256 minStakedToken;
        DepositCondition depositCondition;
        TgeCondition tgeCondition;
        uint256 PRECISION_FACTOR;
        bool isPausedProject;
        uint256 totalUserDeposit;
    }

    struct DepositCondition {
        uint256 startTimestampDeposit;
        uint256 endTimestampDeposit;
    }

    struct TgeCondition {
        uint256 startTimestampTGE;
        uint256 releaseTGE; // percentage = releaseTGE / PRECISION_FACTOR
    }

    /// @dev Project ID => the stages
    mapping(uint256 => Project) public projectAtId;

    // Struct Stage
    struct ClaimStage {
        uint256 startTimestamp;
        uint256 stageRelease;
    }

    /// @dev Project ID => the stages
    mapping(uint256 => ClaimStage[]) public claimStagesAtId;

    /// @dev Project ID => Amount user stake requirement
    mapping(uint256 => mapping(address => uint256)) public userStakeRequirementAtId;

    /// @dev Project ID => Amount user deposit to buy launchpad;
    mapping(uint256 => mapping(address => uint256)) public userDepositAtId;

    /// @dev Project ID => Count user deposit to buy launchpad;
    mapping(uint256 => uint256) public userCountAtId;

    /// @dev Project ID => Count user stake to buy launchpad;
    mapping(uint256 => uint256) public userStakeCountAtId;

    /// @dev Project ID => Is user claimed TGE;
    mapping(uint256 => mapping(address => bool)) public userIsClaimTgeAtId;

    /// @dev Project ID => Is user claimed at stage;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public userIsClaimStageAtId;

    /// @dev Project ID => MerkleRoot;
    mapping(uint256 => bytes32) public merkleRootAtId;

    /// @dev Checks whether caller has DEFAULT_ADMIN_ROLE.
    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "not owner.");
        _;
    }

    /// @dev Checks whether caller has TRANSFER_ROLE.
    modifier onlyTransfer() {
        require(hasRole(TRANSFER_ROLE, _msgSender()), "not transfer role.");
        _;
    }

    // Event
    event InitializeNewProject(uint256 projectId);
    event StakeRequirement(uint256 projectId, address indexed user, uint256 amount);
    event Deposit(uint256 projectId, address indexed user, uint256 amount);
    event Withdraw(uint256 projectId, address indexed user, uint256 amount);
    event WithdrawAll(uint256 projectId, address indexed user, uint256 amount);
    event ClaimedTGE(uint256 projectId, address indexed account, uint256 amount, uint256 time);
    event ClaimedStage(uint256 projectId, address indexed account, uint256 amount, uint256 stageIndex, uint256 time);

    constructor() {
        address deployer = _msgSender();
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);
        _setupRole(TRANSFER_ROLE, deployer);
    }

    function initialize(
        ERC20 _saleToken,
        ERC20 _stakedToken,
        ERC20 _currencyToken,
        uint256 _totalSaleToken,
        uint256 _pricePerSaleToken,
        uint256 _maxCurrencyPerUser,
        uint256 _minCurrencyPerUser,
        uint256 _minStakedToken,
        DepositCondition calldata _depositCondition,
        TgeCondition calldata _tgeCondition,
        uint256 _PRECISION_FACTOR
    ) external onlyOwner {
        require(_saleToken.decimals() == 18);
        require(_stakedToken.decimals() == 18);
        require(_currencyToken.decimals() == 18);

        uint256 currentId = nextProjectId;

        projectAtId[currentId] = Project({
            saleToken: _saleToken,
            stakedToken: _stakedToken,
            currencyToken: _currencyToken,
            totalSaleToken: _totalSaleToken,
            pricePerSaleToken: _pricePerSaleToken,
            maxCurrencyPerUser: _maxCurrencyPerUser,
            minCurrencyPerUser: _minCurrencyPerUser,
            minStakedToken: _minStakedToken,
            depositCondition: _depositCondition,
            tgeCondition: _tgeCondition,
            PRECISION_FACTOR: _PRECISION_FACTOR,
            totalUserDeposit: 0,
            isPausedProject: false
        });

        nextProjectId += 1;

        emit InitializeNewProject(currentId);
    }

    function stakeRequirement(uint256 _projectId, uint256 _amount) external nonReentrant {

        require(
            _amount.add(userStakeRequirementAtId[_projectId][msg.sender]) >= projectAtId[_projectId].minStakedToken,
            "User amount below min"
        );

        if (_amount > 0) {
            userStakeRequirementAtId[_projectId][msg.sender] += _amount;
            projectAtId[_projectId].stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            userStakeCountAtId[_projectId] += 1;
        }

        emit StakeRequirement(_projectId, msg.sender, _amount);
    }

    function deposit(uint256 _projectId, uint256 _amount, bytes32[] calldata _proofs) external nonReentrant {
        Project memory projectDetail = projectAtId[_projectId];
        require(
            block.timestamp >= projectDetail.depositCondition.startTimestampDeposit,
            "Deposit time does not start"
        );
        require(
            block.timestamp <= projectDetail.depositCondition.endTimestampDeposit,
            "Deposit time is ended"
        );
        if (merkleRootAtId[_projectId] != bytes32(0)) {
            require(
                checkUserIsValid(_projectId, _proofs, msg.sender),
                "User is not valid"
            );
        } else {
            require(
                userStakeRequirementAtId[_projectId][msg.sender] >= projectDetail.minStakedToken,
                "Staked token amount do not meet requirement"
            );
        }

        require(
            _amount.add(userDepositAtId[_projectId][msg.sender]) >= projectDetail.minCurrencyPerUser,
            "User amount below minimum"
        );
        require(
            _amount.add(userDepositAtId[_projectId][msg.sender]) <= projectDetail.maxCurrencyPerUser,
            "User amount above maximum"
        );



        if (_amount > 0) {
            userDepositAtId[_projectId][msg.sender] += _amount;
            projectDetail.currencyToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            projectAtId[_projectId].totalUserDeposit += _amount;
            userCountAtId[_projectId] += 1;
        }

        emit Deposit(_projectId, msg.sender, _amount);
    }

    function withdraw(uint256 _projectId, uint256 _amount) external nonReentrant {
        Project memory projectDetail = projectAtId[_projectId];

        require(
            block.timestamp >= projectDetail.depositCondition.startTimestampDeposit,
            "Deposit time does not start"
        );
        require(
            block.timestamp <= projectDetail.depositCondition.endTimestampDeposit,
            "Deposit time is ended"
        );

        require(
            userDepositAtId[_projectId][msg.sender] >= _amount,
            "Amount to withdraw too high"
        );

        require(
            _amount.sub(userDepositAtId[_projectId][msg.sender]) >= projectDetail.minCurrencyPerUser,
            "User amount below minimum"
        );

        if (_amount > 0) {
            userDepositAtId[_projectId][msg.sender] -= _amount;
            projectDetail.currencyToken.safeTransfer(msg.sender, _amount);
            projectAtId[_projectId].totalUserDeposit -= _amount;
        }

        emit Withdraw(_projectId, msg.sender, _amount);
    }

    function withdrawAll(uint256 _projectId) external nonReentrant {
        Project memory projectDetail = projectAtId[_projectId];
        uint256 _amount = userDepositAtId[_projectId][msg.sender];

        require(
            block.timestamp >= projectDetail.depositCondition.startTimestampDeposit,
            "Deposit time does not start"
        );
        require(
            block.timestamp <= projectDetail.depositCondition.endTimestampDeposit,
            "Deposit time is ended"
        );

        if (_amount > 0) {
            projectDetail.currencyToken.safeTransfer(msg.sender, _amount);
            projectAtId[_projectId].totalUserDeposit -= _amount;
            userDepositAtId[_projectId][msg.sender] = 0;
            userCountAtId[_projectId] -= 1;
        }

        emit WithdrawAll(_projectId, msg.sender, _amount);
    }

    function claimStakeRequirement(uint256 _projectId) external nonReentrant {
        if (userStakeRequirementAtId[_projectId][msg.sender] > 0) {
            projectAtId[_projectId].stakedToken.safeTransfer(msg.sender, userStakeRequirementAtId[_projectId][msg.sender]);
            userStakeRequirementAtId[_projectId][msg.sender] = 0;
            userStakeCountAtId[_projectId] -= 1;
        }
    }

    // Claim at TGE
    function claimTGE(uint256 _projectId) external nonReentrant {
        Project memory projectDetail = projectAtId[_projectId];
        require(
            projectDetail.isPausedProject != true,
            "This project is paused!"
        );

        require(
            userDepositAtId[_projectId][msg.sender] > 0,
            "You did not deposit to buy"
        );

        require(
            userIsClaimTgeAtId[_projectId][msg.sender] == false,
            "TGE is claimed"
        );

        require(
            block.timestamp >= projectDetail.tgeCondition.startTimestampTGE,
            "TGE not release"
        );

        // calc token allocation
        uint256 percentageAllocation = (userDepositAtId[_projectId][msg.sender].mul(10**18).div(projectDetail.totalUserDeposit)).min(
            userDepositAtId[_projectId][msg.sender].div(projectDetail.totalSaleToken.mul(projectDetail.pricePerSaleToken).div(10**36))
        );
        uint256 userRemaining = userDepositAtId[_projectId][msg.sender].sub(percentageAllocation.mul(projectDetail.totalSaleToken.mul(projectDetail.pricePerSaleToken).div(10**36)));

        if (userStakeRequirementAtId[_projectId][msg.sender] > 0) {
            projectDetail.stakedToken.safeTransfer(msg.sender, userStakeRequirementAtId[_projectId][msg.sender]);
            userStakeRequirementAtId[_projectId][msg.sender] = 0;
        }

        if (userRemaining > 0) {
            projectDetail.currencyToken.safeTransfer(msg.sender, userRemaining);
        }
        // calc token can claim TGE
        uint256 amountUser = percentageAllocation.mul(projectDetail.totalSaleToken).div(10**18);
        uint256 amountClaimTGE = amountUser.mul(projectDetail.tgeCondition.releaseTGE).div(projectDetail.PRECISION_FACTOR);

        projectDetail.saleToken.safeTransfer(msg.sender, amountClaimTGE);
        // Set userIsClaimTGE
        userIsClaimTgeAtId[_projectId][msg.sender] = true;

        emit ClaimedTGE(_projectId, msg.sender, amountClaimTGE, block.timestamp);
    }

    // Claim Stage
    function claimStage(uint256 _projectId, uint256 _stageIndex) external nonReentrant {
        Project memory projectDetail = projectAtId[_projectId];

        require(projectDetail.isPausedProject != true, "This contract is pause!");
        require(_stageIndex <= claimStagesAtId[_projectId].length - 1, "Not valid stage index");

        ClaimStage memory stage = claimStagesAtId[_projectId][_stageIndex];

        require(
            block.timestamp >= projectDetail.depositCondition.endTimestampDeposit,
            "Deposit time is not ended"
        );
        require(
            block.timestamp >= stage.startTimestamp,
            "Stage not release"
        );
        require(
            userIsClaimStageAtId[_projectId][msg.sender][_stageIndex] != true,
            "This stage is claimed"
        );

        // calc amount claim
        uint256 percentageAllocation = (userDepositAtId[_projectId][msg.sender].mul(10**18).div(projectDetail.totalUserDeposit)).min(
            userDepositAtId[_projectId][msg.sender].div(projectDetail.totalSaleToken.mul(projectDetail.pricePerSaleToken).div(10**36))
        );
        uint256 amountUser = percentageAllocation.mul(projectDetail.totalSaleToken).div(10**18);
        uint256 amountClaimByStage = amountUser.mul(stage.stageRelease).div(projectDetail.PRECISION_FACTOR);

        projectDetail.saleToken.safeTransfer(msg.sender, amountClaimByStage);

        // Set userIsClaimStageAtId
        userIsClaimStageAtId[_projectId][msg.sender][_stageIndex] = true;

        emit ClaimedStage(_projectId, msg.sender, amountClaimByStage, _stageIndex, block.timestamp);
    }

    // Set Deposit time
    function setDepositTime(uint256 _projectId, DepositCondition calldata _depositCondition) external onlyOwner {
        require(
            block.timestamp < projectAtId[_projectId].depositCondition.startTimestampDeposit,
            "Launchpad has been running"
        );
        require(
            _depositCondition.startTimestampDeposit < _depositCondition.endTimestampDeposit,
            "Time rage is not valid"
        );

        projectAtId[_projectId].depositCondition = _depositCondition;
    }

    // Set TGE time
    function setTGE(uint256 _projectId, TgeCondition calldata _tgeCondition) external onlyOwner {
        Project memory projectDetail = projectAtId[_projectId];
        require(
            block.timestamp < projectDetail.depositCondition.startTimestampDeposit,
            "Launchpad has been running"
        );

        require(
            _tgeCondition.startTimestampTGE > projectDetail.depositCondition.endTimestampDeposit,
            "TGE is must after deposit time"
        );

        uint256 totalPercentage;

        for (uint256 i = 0; i < claimStagesAtId[_projectId].length; i++) {
            totalPercentage += claimStagesAtId[_projectId][i].stageRelease;
        }
        require(
            totalPercentage.add(_tgeCondition.releaseTGE) == projectDetail.PRECISION_FACTOR,
            "PRECISION_FACTOR is not equal total percentage"
        );

        projectAtId[_projectId].tgeCondition = _tgeCondition;
    }

    // Set all stage claim
    function setStages(uint256 _projectId, ClaimStage[] calldata _stages) external onlyOwner {
        // make sure the conditions are sorted in ascending order
        uint256 lastStartTimestamp;
        uint256 totalPercentage;
        delete claimStagesAtId[_projectId];

        for (uint256 i = 0; i < _stages.length; i++) {
            require(
                lastStartTimestamp == 0 || lastStartTimestamp < _stages[i].startTimestamp,
                "startTimestamp must be in ascending order."
            );

            claimStagesAtId[_projectId].push(ClaimStage({
            stageRelease: _stages[i].stageRelease,
            startTimestamp: _stages[i].startTimestamp
            }));

            totalPercentage += _stages[i].stageRelease;
        }

        assert(totalPercentage.add(projectAtId[_projectId].tgeCondition.releaseTGE) == projectAtId[_projectId].PRECISION_FACTOR);
    }

    // Update single stage by stage index
    function updateStage(uint256 _projectId, uint256 _stageIndex, uint256 _stageRelease, uint256 _startTimestamp) external onlyOwner {

        uint256 totalPercentage;
        for (uint256 i = 0; i < claimStagesAtId[_projectId].length; i++) {
            if (_stageIndex == i) {
                totalPercentage += _stageRelease;
            } else {
                totalPercentage += claimStagesAtId[_projectId][i].stageRelease;
            }
        }
        require(totalPercentage.add(projectAtId[_projectId].tgeCondition.releaseTGE) == projectAtId[_projectId].PRECISION_FACTOR, 'PRECISION_FACTOR is not equal total percentage');

        claimStagesAtId[_projectId][_stageIndex] = ClaimStage({
        stageRelease: _stageRelease,
        startTimestamp: _startTimestamp
        });
    }

    // Update project info
    function updateProjectMinMaxCurrency(uint256 _projectId, uint256 _minCurrencyPerUser, uint256 _maxCurrencyPerUser)  external onlyOwner {
        Project memory projectDetail = projectAtId[_projectId];
        require(
            block.timestamp < projectDetail.depositCondition.startTimestampDeposit,
            "Launchpad has been running"
        );

        require(
            _minCurrencyPerUser <= _maxCurrencyPerUser,
            "Min - Max not valid"
        );

        projectAtId[_projectId].minCurrencyPerUser = _minCurrencyPerUser;
        projectAtId[_projectId].maxCurrencyPerUser = _maxCurrencyPerUser;
    }

    // Update project info
    function updateProjectSale(uint256 _projectId, uint256 _totalSaleToken, uint256 _pricePerSaleToken)  external onlyOwner {
        Project memory projectDetail = projectAtId[_projectId];
        require(
            block.timestamp < projectDetail.depositCondition.startTimestampDeposit,
            "Launchpad has been running"
        );

        projectAtId[_projectId].totalSaleToken = _totalSaleToken;
        projectAtId[_projectId].pricePerSaleToken = _pricePerSaleToken;
    }

    // Return number of stage range
    function getAllStage(uint256 _projectId) public view returns (uint256) {
        return claimStagesAtId[_projectId].length;
    }

    // Update pause project status
    function pauseProject(uint256 _projectId, bool _bool) external onlyOwner {
        projectAtId[_projectId].isPausedProject = _bool;
    }

    function setMerkleRoot(uint256 _projectId, bytes32 _root) external onlyOwner {
        merkleRootAtId[_projectId] = _root;
    }

    function checkUserIsValid(uint256 _projectId, bytes32[] calldata _proofs, address _claimer) public view returns (bool) {
        bytes32 merkleRoot = merkleRootAtId[_projectId];
        if (merkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(_claimer));
            return MerkleProof.verify(_proofs, merkleRoot, leaf);
        }
        return true;
    }

    /* ========== EMERGENCY ========== */
    function withdrawToken(address _token, address _to, uint256 _amount) external onlyTransfer {
        ERC20(_token).transfer(_to, _amount);
    }
}