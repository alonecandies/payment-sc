// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SubscriptionPaymentStorage} from "./SubscriptionPaymentStorage.sol";
import "./ISubscriptionPayment.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract SubscriptionPaymentImpl is
    Initializable,
    SubscriptionPaymentStorage,
    ISubscriptionPayment,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(address _admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    receive() external payable {}

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "unauthorized: admin required"
        );
        _;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    constructor(address _feeTokenAddress) {
        feeToken = IERC20Upgradeable(_feeTokenAddress);
    }

    function setFeeToken(address _feeTokenAddress) external onlyAdmin {
        feeToken = IERC20Upgradeable(_feeTokenAddress);
    }

    function setPlan(
        uint256 _planType,
        uint256 _monthlyFee,
        uint256 _yearlyFee
    ) external onlyAdmin {
        require(_planType > 0, "Invalid plan type");
        require(_monthlyFee > 0, "Invalid monthly fee");
        require(_yearlyFee > 0, "Invalid yearly fee");
        plans[_planType] = Plan(_planType, _monthlyFee, _yearlyFee);
        emit SetPlan(_planType, _monthlyFee, _yearlyFee);
    }

    function getPlan(uint256 _planType) public view returns (Plan memory) {
        return plans[_planType];
    }

    function subscribe(
        bytes32 subscriptionPeriod,
        uint256 planType,
        bool autoRenewEnabled
    ) external override whenNotPaused {
        require(
            isSubscribed(msg.sender, planType) == false,
            "User already subscribed"
        );

        require(
            subscriptionPeriod == "month" || subscriptionPeriod == "year",
            "Invalid subscription plan"
        );

        // mapping(uint256 => Plan) public plans;
        require(
            planType > 0 && plans[planType].planType > 0,
            "Invalid plan type"
        );

        uint256 monthlyFee = plans[planType].monthlyFee;
        uint256 yearlyFee = plans[planType].yearlyFee;

        uint256 expiry = block.timestamp +
            (subscriptionPeriod == "year" ? YEAR_IN_SECONDS : MONTH_IN_SECONDS);
        feeToken.safeTransferFrom(
            msg.sender,
            address(this),
            subscriptionPeriod == "year" ? yearlyFee : monthlyFee
        );

        userSubscriptions[msg.sender][planType] = Subscription(
            subscriptionPeriod,
            planType,
            expiry,
            autoRenewEnabled
        );

        emit Subscribe(msg.sender, planType, expiry, autoRenewEnabled);
    }

    function extendSubscription(
        address user,
        bytes32 subscriptionPeriod,
        uint256 planType
    ) external override whenNotPaused {
        require(isSubscribed(user, planType) == true, "User not subscribed");

        require(
            subscriptionPeriod == "month" || subscriptionPeriod == "year",
            "Invalid subscription plan"
        );

        require(
            planType > 0 && plans[planType].planType > 0,
            "Invalid plan type"
        );

        uint256 monthlyFee = plans[planType].monthlyFee;
        uint256 yearlyFee = plans[planType].yearlyFee;

        Subscription storage subscription = userSubscriptions[user][planType];
        uint256 expiry = subscription.expiry;
        uint256 newExpiry = expiry +
            (subscriptionPeriod == "year" ? YEAR_IN_SECONDS : MONTH_IN_SECONDS);
        feeToken.safeTransferFrom(
            msg.sender,
            address(this),
            subscriptionPeriod == "year" ? yearlyFee : monthlyFee
        );
        subscription.expiry = newExpiry;
        emit ExtendSubscription(user, planType, newExpiry);
    }

    function enableAutoRenew(address user, uint256 planType) external {
        Subscription storage subscription = userSubscriptions[user][planType];
        require(subscription.expiry > 0, "User not subscribed");
        subscription.autoRenewEnabled = true;
    }

    function disableAutoRenew(address user, uint256 planType) external {
        Subscription storage subscription = userSubscriptions[user][planType];
        require(subscription.expiry > 0, "User not subscribed");
        subscription.autoRenewEnabled = false;
    }

    function isSubscribed(
        address user,
        uint256 planType
    ) public view returns (bool) {
        Subscription storage subscription = userSubscriptions[user][planType];
        return subscription.expiry > 0;
    }

    function withdrawTokens(
        address tokenAddress,
        uint256 amount,
        address sendTo
    ) external onlyAdmin {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.safeTransfer(sendTo, amount);
    }

    function withdrawEther(
        uint256 amount,
        address payable sendTo
    ) external onlyAdmin {
        (bool success, ) = sendTo.call{value: amount}("");
        require(success, "withdraw failed");
    }

    fallback() external payable {
        revert("Invalid transaction");
    }
}
