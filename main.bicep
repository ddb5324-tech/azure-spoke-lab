param location string = resourceGroup().location
param adminUsername string = 'Demouser'
param sshPublicKey string
@description('Your public IP in CIDR form, e.g. 203.0.113.5/32')
param allowedSshSource string
param vmSize string = 'Standard_B2s'

resource nsg1 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-spoke1'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-MyIP'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSshSource
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-spoke2'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet1 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-spoke1'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [
      {
        name: 'snet-spoke1'
        properties: {
          addressPrefix: '10.1.0.0/24'
          networkSecurityGroup: { id: nsg1.id }
        }
      }
    ]
  }
}

resource vnet2 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-spoke2'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [
      {
        name: 'snet-spoke2'
        properties: {
          addressPrefix: '10.2.0.0/24'
          networkSecurityGroup: { id: nsg2.id }
        }
      }
    ]
  }
}

resource peer1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnet1
  name: 'spoke1-to-spoke2'
  properties: {
    remoteVirtualNetwork: { id: vnet2.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
  }
}

resource peer2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnet2
  name: 'spoke2-to-spoke1'
  properties: {
    remoteVirtualNetwork: { id: vnet1.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
  }
}

resource pip1 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-vm1-spoke1'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource nic1 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-vm1-spoke1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet1.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: pip1.id, properties: { deleteOption: 'Delete' } }
        }
      }
    ]
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-vm2-spoke2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet2.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'vm1-spoke1'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'vm1-spoke1'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            { path: '/home/${adminUsername}/.ssh/authorized_keys', keyData: sshPublicKey }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: 'ubuntu-24_04-lts', sku: 'server', version: 'latest' }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nic1.id, properties: { deleteOption: 'Delete' } }]
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'vm2-spoke2'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'vm2-spoke2'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            { path: '/home/${adminUsername}/.ssh/authorized_keys', keyData: sshPublicKey }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: 'ubuntu-24_04-lts', sku: 'server', version: 'latest' }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nic2.id, properties: { deleteOption: 'Delete' } }]
    }
  }
}

output spoke1PublicIp string = pip1.properties.ipAddress
