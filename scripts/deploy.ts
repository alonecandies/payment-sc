import { ethers, hardhatArguments } from "hardhat";
import * as Config from "./config";

async function main() {
  await Config.initConfig();
  const network = hardhatArguments.network ? hardhatArguments.network : "dev";
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const subscriptionPayment = await ethers.deployContract(
    "SubscriptionPayment"
  );
  Config.setConfig(
    network + ".subscriptionPayment",
    await subscriptionPayment.getAddress()
  );

  const subscriptionPaymentImplFactory = await ethers.getContractFactory(
    "SubscriptionPaymentImpl"
  );
  const subscriptionPaymentImpl = await subscriptionPaymentImplFactory.deploy(
    "0x"
  );
  await subscriptionPaymentImpl.waitForDeployment();
  Config.setConfig(
    network + ".subscriptionPaymentImpl",
    await subscriptionPaymentImpl.getAddress()
  );

  console.log(
    "SubscriptionPayment address:",
    await subscriptionPayment.getAddress()
  );

  console.log(
    "SubscriptionPaymentImpl address:",
    await subscriptionPaymentImpl.getAddress()
  );

  Config.saveConfig();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
