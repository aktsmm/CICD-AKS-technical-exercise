@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('管理者パスワード')
@secure()
param adminPassword string

@description('サブネットID')
param subnetId string

@description('SSH公開許可（脆弱性）')
param allowSSHFromInternet bool = true

@description('古いOSバージョン使用（脆弱性）')
param useOldOSVersion bool = true

var vmName = 'vm-mongo-${environment}'
var nicName = '${vmName}-nic'
var nsgName = '${vmName}-nsg'
var publicIPName = '${vmName}-pip'

// Public IP（脆弱性: VM直接公開）
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NSG（脆弱性: SSH全開放）
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowSSHFromInternet ? '*' : 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-MongoDB'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '27017'
          sourceAddressPrefix: '*'  // 脆弱性: MongoDB全開放
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// NIC
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// VM（脆弱性: 古いUbuntu 18.04）
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: 'azureuser'  // Hardcoded for demo vulnerability purposes
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: useOldOSVersion ? '18.04-LTS' : '22.04-LTS'  // 脆弱性: 古いOS
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// MongoDB インストールスクリプト（認証なし = 脆弱性）
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'install-mongodb'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: '''
        #!/bin/bash
        apt-get update
        apt-get install -y mongodb
        
        # 脆弱性: 認証無効、全IPからアクセス許可
        sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
        sed -i 's/#port = 27017/port = 27017/' /etc/mongodb.conf
        
        systemctl restart mongodb
        systemctl enable mongodb
      '''
    }
  }
}

output publicIP string = publicIP.properties.ipAddress
output privateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
