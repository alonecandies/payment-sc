// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SubscriptionPaymentStorage} from "./SubscriptionPaymentStorage.sol";
import "./ISubscriptionPayment.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SubscriptionPaymentImpl is
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

    function setPlan(
        uint256 _planType,
        uint256 _monthlyFee,
        uint256 _yearlyFee
    ) external onlyAdmin {
        require(_planType > 0, "Invalid plan type");
        require(_monthlyFee > 0, "Invalid monthly fee");
        require(_yearlyFee > 0, "Invalid yearly fee");
        bool planExists = false;
        for (uint256 i = 0; i < plans.length; i++) {
            if (plans[i].planType == _planType) {
                planExists = true;
                plans[i].monthlyFee = _monthlyFee;
                plans[i].yearlyFee = _yearlyFee;
                break;
            }
        }
        if (!planExists) {
            plans.push(Plan(_planType, _monthlyFee, _yearlyFee));
        }
        emit SetPlan(_planType, _monthlyFee, _yearlyFee);
    }

    function getPlans()
        external
        view
        returns (SubscriptionPaymentStorage.Plan[] memory)
    {
        return plans;
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

        require(planType > 0 && planType <= plans.length, "Invalid plan type");

        uint256 monthlyFee;
        uint256 yearlyFee;
        for (uint256 i = 0; i < plans.length; i++) {
            if (plans[i].planType == planType) {
                monthlyFee = plans[i].monthlyFee;
                yearlyFee = plans[i].yearlyFee;
                break;
            }
        }

        uint256 expiry = block.timestamp +
            (subscriptionPeriod == "year" ? YEAR_IN_SECONDS : MONTH_IN_SECONDS);
        feeToken.safeTransferFrom(
            msg.sender,
            address(this),
            subscriptionPeriod == "year" ? yearlyFee : monthlyFee
        );

        userSubscriptions[msg.sender].push(
            Subscription(subscriptionPeriod, planType, expiry, autoRenewEnabled)
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

        require(planType > 0 && planType <= plans.length, "Invalid plan type");

        uint256 monthlyFee;
        uint256 yearlyFee;
        for (uint256 i = 0; i < plans.length; i++) {
            if (plans[i].planType == planType) {
                monthlyFee = plans[i].monthlyFee;
                yearlyFee = plans[i].yearlyFee;
                break;
            }
        }

        Subscription[] storage subscriptions = userSubscriptions[user];
        for (uint256 i = 0; i < subscriptions.length; i++) {
            if (subscriptions[i].planType == planType) {
                uint256 expiry = subscriptions[i].expiry;
                uint256 newExpiry = expiry +
                    (
                        subscriptionPeriod == "year"
                            ? YEAR_IN_SECONDS
                            : MONTH_IN_SECONDS
                    );
                feeToken.safeTransferFrom(
                    msg.sender,
                    address(this),
                    subscriptionPeriod == "year" ? yearlyFee : monthlyFee
                );
                subscriptions[i].expiry = newExpiry;
                emit ExtendSubscription(user, planType, newExpiry);
                break;
            }
        }
    }

    function enableAutoRenew(address user, uint256 planType) external {
        Subscription[] storage subscriptions = userSubscriptions[user];
        for (uint256 i = 0; i < subscriptions.length; i++) {
            if (subscriptions[i].planType == planType) {
                subscriptions[i].autoRenewEnabled = true;
                break;
            }
        }
    }

    function disableAutoRenew(address user, uint256 planType) external {
        Subscription[] storage subscriptions = userSubscriptions[user];
        for (uint256 i = 0; i < subscriptions.length; i++) {
            if (subscriptions[i].planType == planType) {
                subscriptions[i].autoRenewEnabled = false;
                break;
            }
        }
    }

    function isSubscribed(
        address user,
        uint256 planType
    ) public view returns (bool) {
        Subscription[] storage subscriptions = userSubscriptions[user];
        for (uint256 i = 0; i < subscriptions.length; i++) {
            if (subscriptions[i].planType == planType) {
                return true;
            }
        }
        return false;
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
}
