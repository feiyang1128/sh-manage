GL.iNet MT3000 管理脚本

这是一个适用于 GL.iNet MT3000 路由器的管理脚本，旨在简化 OpenWrt 系统管理、软件安装和更新等操作。

安装脚本

通过以下命令一键安装或更新管理脚本：

bash -c "$(curl -sL https://sh.feiyang.gq/openwrt.sh)"


该命令会下载并执行最新版本的管理脚本。脚本安装完成后，您可以通过命令行进行配置和管理。

脚本功能

此脚本提供了一些常见的路由器管理功能，以下是当前支持的功能：

1. 更新软件源

使用此选项更新 OpenWrt 系统的软件源：

更新软件源

2. 安装 OpenClash

OpenClash 是一个 OpenWrt 上的 Clash 客户端，支持科学上网。

安装 OpenClash

3. 安装 iStore

iStore 是一个应用商店，提供了众多 OpenWrt 系统的插件。

安装 iStore

4. 卸载 OpenClash

如果您不再需要 OpenClash，可以通过此选项卸载它：

卸载 OpenClash

5. 卸载 iStore

通过此选项卸载 iStore 和其依赖包：

卸载 iStore

6. 安装 SFTP 服务

如果您需要使用 SFTP 服务，您可以通过此选项安装：

安装 SFTP 服务

7. 卸载 SFTP 服务

如果您不再需要 SFTP 服务，可以通过此选项卸载它：

卸载 SFTP 服务

8. 更新脚本

您可以随时使用此选项更新脚本，确保获得最新功能和修复：

更新脚本

9. 删除脚本文件

如果您想删除脚本文件，可以使用此选项：

删除脚本文件


该操作会删除当前下载的脚本文件，并清理相关数据。

使用方法

在路由器中使用 SSH 连接到您的 GL.iNet MT3000。

执行以下命令来安装脚本：

bash -c "$(curl -sL https://sh.feiyang.gq/openwrt.sh)"


根据菜单提示选择您要执行的操作。

