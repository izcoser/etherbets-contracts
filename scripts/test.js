const { ethers } = require('hardhat');
const abi = require('./etherbetsv2abi.json');
const pk = require('../hardhat.config.js').networks.goerli.accounts[0];
const pk2 = require('../hardhat.config.js').networks.goerli.accounts[1];
const url = require('../hardhat.config.js').networks.goerli.url;

async function main(){
    
    const address = "0x052B9576cd581D26385016c45e3ceb6e15BcA91B";
    const provider = ethers.getDefaultProvider(url);
    const signer = new ethers.Wallet(pk, provider);
    const signer2 = new ethers.Wallet(pk2, provider);

    const contract = new ethers.Contract(address, abi, signer);
    const contract2 = new ethers.Contract(address, abi, signer2); 
    console.log('Placing bets.');
    for(let i = 0; i < 5; i++){
      if(Math.floor(Math.random() * 10) % 2 == 0){
        await contract.placeBet(3, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
        await contract.placeBet(5, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
        await contract.placeBet(6, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
      }
      else{
        await contract2.placeBet(3, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
        await contract2.placeBet(5, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
        await contract2.placeBet(6, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
      }
    }
    console.log('Bets placed.');
    //await contract.beginDraw().catch((err) => { console.log(err)});
  }
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });