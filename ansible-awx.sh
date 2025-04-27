#!/bin/bash
# ================================================
# AWX 自动化部署脚本
# 作者: 27hrs
# 版本: v1.0.0
# 创建日期: 2025-04-26
# 功能: 自动完成AWX 10.0.0环境部署
# ================================================

set -e  # 遇到错误立即退出
START_TIME=$(date +%s)  # 记录脚本开始时间

# 初始化环境配置
echo -e "\n\e[32m[步骤1/13] 配置DNS解析...\e[0m"
echo "nameserver 223.5.5.5" >> /etc/resolv.conf

# 配置软件源
echo -e "\n\e[32m[步骤2/13] 清理并配置YUM源...\e[0m"
rm -rf /etc/yum.repos.d/*
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
yum repolist
sudo yum install -y yum-utils
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum repolist
curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo

# 安装基础依赖
echo -e "\n\e[32m[步骤3/13] 安装系统组件...\e[0m"
yum -y install ansible bash-completion yum-utils device-mapper-persistent-data lvm2

# Docker安装配置
echo -e "\n\e[32m[步骤4/13] 安装Docker引擎...\e[0m"
yum install -y docker-ce docker-ce-cli containerd.io
systemctl start docker && systemctl enable docker

# 配置镜像加速
echo -e "\n\e[32m[步骤5/13] 配置Docker镜像加速...\e[0m"
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://k2h4j70n.mirror.aliyuncs.com"]
}
EOF
systemctl daemon-reload && systemctl restart docker

# Python环境配置
echo -e "\n\e[32m[步骤6/13] 配置Python环境...\e[0m"
yum -y install python3-pip
python3 -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple/ --upgrade pip
pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple/ docker-compose

# AWX部署准备
echo -e "\n\e[32m[步骤7/13] 解压AWX安装包...\e[0m"
tar -xvf awx-10.0.0.tar.gz
sed -i.bak 's/env python/env python3/g' awx-10.0.0/installer/inventory

# 拉取Docker镜像
echo -e "\n\e[32m[步骤8/13] 拉取AWX组件镜像...\e[0m"
declare -a IMAGES=(
  "awx_web:10.0.0"
  "awx_task:10.0.0"
  "memcached:alpine"
  "postgres:10"
  "redis"
)
for img in "${IMAGES[@]}"; do
  docker pull "registry.cn-hangzhou.aliyuncs.com/loong576/${img}"
done

# 镜像标签修改
echo -e "\n\e[32m[步骤9/13] 修改镜像标签...\e[0m"
docker tag registry.cn-hangzhou.aliyuncs.com/loong576/awx_task:10.0.0 ansible/awx_task:10.0.0
docker tag registry.cn-hangzhou.aliyuncs.com/loong576/awx_web:10.0.0 ansible/awx_web:10.0.0
docker tag registry.cn-hangzhou.aliyuncs.com/loong576/redis redis
docker tag registry.cn-hangzhou.aliyuncs.com/loong576/postgres:10 postgres:10
docker tag registry.cn-hangzhou.aliyuncs.com/loong576/memcached:alpine memcached:alpine

# 清理原始镜像
echo -e "\n\e[32m[步骤10/13] 清理临时镜像...\e[0m"
docker rmi registry.cn-hangzhou.aliyuncs.com/loong576/awx_web:10.0.0 \
  registry.cn-hangzhou.aliyuncs.com/loong576/redis \
  registry.cn-hangzhou.aliyuncs.com/loong576/postgres:10 \
  registry.cn-hangzhou.aliyuncs.com/loong576/memcached:alpine

# 安装SELinux支持
echo -e "\n\e[32m[步骤11/13] 安装SELinux支持...\e[0m"
yum install libselinux-python3 -y
cd awx-10.0.0/installer
# 执行Ansible部署
echo -e "\n\e[32m[步骤12/13] 开始AWX部署...\e[0m"
source /etc/profile.d/bash_completion.sh
ansible-playbook -i inventory install.yml

# 计算执行时间
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

echo -e "\n\e[32m[步骤13/13] 部署完成!\e[0m"
echo -e "===============================================
总耗时: $((ELAPSED_TIME/60)) 分 $((ELAPSED_TIME%60)) 秒
AWX管理界面访问地址: http://服务器IP:端口
默认管理员账号: admin
默认管理员密码: 请查看安装目录password.txt
==============================================="