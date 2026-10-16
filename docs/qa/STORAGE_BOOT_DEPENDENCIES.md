# Docker 存储启动依赖与 MariaDB 恢复

2026-10-16。配置源码 `a3f734a`；本记录不等于已经完成重启、掉盘或灾备演练。

## 现场与恢复

重连后 MariaDB 是退出状态，退出码127、非OOM。OCI错误明确指向配置文件 bind mount 的文件/目录类型不匹配。现场 `/data` 是独立 HDD ext4 挂载；NVMe运行目录位于NVMe根分区。Docker 于08:04:49启动，`data.mount` 于08:05:08才就绪，且 Docker 原先没有该挂载依赖。当前配置文件为正常文件，数据挂载完成后原容器正常启动并恢复 healthy，支持启动顺序导致失败的判断。未删除/搬迁数据目录，未重建 MariaDB、未同时运行第二个实例。

## 已落地与证据

- 新增 root 所有 Docker drop-in，`RequiresMountsFor` 指向配置仓库、NVMe运行和HDD备份路径。安装前必须已经挂载 `/data`，并有持久 fstab/systemd 挂载定义；拒绝符号链接或非本安装器管理的目标配置。
- `install-dependencies.sh` 已接入该步骤，位于数据目录创建和启动依赖之前。MariaDB配置文件改为长格式只读 bind、`create_host_path:false`。
- 实际安装连续执行2次成功；Docker的 `ActiveEnterTimestampMonotonic` 前后相同，没有为应用此配置重启Docker。
- `systemctl show docker` 的 Requires 和 After 已包含 `data.mount`，RequiresMountsFor 三个路径正确；配置文件为 root:root/0644。
- 实际 Compose 配置校验通过。独立随机 Compose 项目使用现有不可变 MariaDB image ID，只执行 create、不启动：缺失配置被引擎拒绝，宿主缺失源未创建，没有容器/网络残留；临时文件已清理。脚本为 `scripts/test-storage-bind.sh`。
- 现有 MariaDB 容器保留原配置运行，新的 `create_host_path:false` 在以后重建时生效；本次即时保护来自已安装的 systemd 启动依赖。没有为此额外重建数据库。

## 后续

在授权维护窗口验证实际主机重启、挂载失败和恢复行为，再签收完整启动故障门槛；不为测试擅自重启工作站或卸载生产HDD。异地备份仍是独立剩余工作。Whale Deck完整P0–P5范围不变。
