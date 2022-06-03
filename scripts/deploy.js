async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("contracts/EtherBets.sol:EtherBets");
  const token = await Token.deploy("Mega Sena", ethers.utils.parseEther("0.01"), 60, 6, 120, "0x63B9d642887dd6D7E35A822382a2cBf5Eb49fdfB");

  console.log("Token address:", token.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });