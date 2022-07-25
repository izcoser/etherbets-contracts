// Deploys TheRundownConsumer on the Kovan testnet.
async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const Token = await ethers.getContractFactory("contracts/SportsDataIOConsumer.sol:SportsdataioLinkPoolConsumerOracle");
    const token = await Token.deploy("0xa36085F69e2889c224210F603D836748e7dC0088", "0xfF07C97631Ff3bAb5e5e5660Cdf47AdEd8D4d4Fd");
    
  
    console.log("SportsdataioLinkPoolConsumerOracle address:", token.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });