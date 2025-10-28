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

@description('Storage Account名（バックアップ先）')
param storageAccountName string

@description('バックアップコンテナ名')
param backupContainerName string = 'backups'

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
          sourceAddressPrefix: '10.0.0.0/16'  // 修正: VNet内(Kubernetesネットワーク)からのみ許可
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
  identity: {
    type: 'SystemAssigned'  // 脆弱性: 過剰な権限付与のためManaged Identityを有効化
  }
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
        set -e
        
        # MongoDB インストール
        apt-get update
        apt-get install -y mongodb mongodb-clients
        
        # 脆弱性: 認証無効、全IPからアクセス許可
        sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
        sed -i 's/#port = 27017/port = 27017/' /etc/mongodb.conf
        
        systemctl restart mongodb
        systemctl enable mongodb
        
        # Azure CLI インストール（バックアップ用）
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
        
        # バックアップディレクトリ作成
        mkdir -p /var/backups/mongodb
        
        # バックアップスクリプト作成
        cat > /usr/local/bin/mongodb-backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/mongodb"
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.tar.gz"

# MongoDB バックアップ（認証なしでダンプ）
mongodump --out ${BACKUP_DIR}/dump_${TIMESTAMP}

# 圧縮
cd ${BACKUP_DIR}
tar -czf ${BACKUP_FILE} dump_${TIMESTAMP}
rm -rf dump_${TIMESTAMP}

# Azure Storage にアップロード（Managed Identity 使用）
az storage blob upload \
  --account-name STORAGE_ACCOUNT_NAME \
  --container-name BACKUP_CONTAINER \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --auth-mode login

# ローカルバックアップは7日間保持
find ${BACKUP_DIR} -name "mongodb_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}"
BACKUP_SCRIPT
        
        chmod +x /usr/local/bin/mongodb-backup.sh
        
        # Storage Account情報を環境変数として設定
        sed -i "s/STORAGE_ACCOUNT_NAME/${storageAccountName}/g" /usr/local/bin/mongodb-backup.sh
        sed -i "s/BACKUP_CONTAINER/${backupContainerName}/g" /usr/local/bin/mongodb-backup.sh
        
        # Managed Identity でログイン
        az login --identity
        
        # Cron ジョブ設定（毎日午前2時にバックアップ）
        echo "0 2 * * * /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1" | crontab -
        
        # 初回バックアップを即座に実行
        /usr/local/bin/mongodb-backup.sh
      '''
    }
  }
}

output publicIP string = publicIP.properties.ipAddress
output privateIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmIdentityPrincipalId string = vm.identity.principalId
