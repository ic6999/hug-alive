#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"
PROJECT_DIR_NAME="python-xray-argo"

# 静默安装模式函数
auto_install_mode() {
    echo -e "${GREEN}启动静默安装模式...${NC}"
    
    # 检查必要的环境变量或设置默认值
    if [ -z "$UUID" ]; then
        UUID=$(generate_uuid)
        echo -e "${YELLOW}UUID未设置，使用自动生成: $UUID${NC}"
    fi
    
    # 设置其他变量的默认值
    : ${NAME:="Xray-Node"}
    : ${PORT:=3000}
    : ${CFIP:="joeyblog.net"}
    : ${CFPORT:=443}
    : ${SUB_PATH:="sub"}
    : ${ARGO_PORT:=3000}
    : ${KEEP_ALIVE_HF:="false"}
    
    echo -e "${BLUE}使用配置:${NC}"
    echo -e "UUID: $UUID"
    echo -e "节点名称: $NAME"
    echo -e "服务端口: $PORT"
    echo -e "优选IP: $CFIP"
    echo -e "优选端口: $CFPORT"
    echo -e "订阅路径: $SUB_PATH"
    echo -e "HuggingFace保活: $KEEP_ALIVE_HF"
    
    # 检查并安装依赖
    install_dependencies
    
    # 下载项目
    if [ ! -d "$PROJECT_DIR_NAME" ]; then
        echo -e "${BLUE}下载项目仓库...${NC}"
        download_project
    fi
    
    cd "$PROJECT_DIR_NAME"
    
    # 配置app.py
    configure_app_auto
    
    # 启动服务
    start_service_auto
    
    # 保存配置信息
    save_config_info
    
    echo -e "${GREEN}静默安装完成!${NC}"
    exit 0
}

# UUID生成函数
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

# 安装依赖函数
install_dependencies() {
    echo -e "${BLUE}检查并安装依赖...${NC}"
    
    # 检查并安装Python3[8](@ref)
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}正在安装 Python3...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y python3 python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3 python3-pip
        else
            echo -e "${RED}无法自动安装Python3，请手动安装${NC}"
            exit 1
        fi
    fi
    
    # 检查并安装requests库
    if ! python3 -c "import requests" &> /dev/null; then
        echo -e "${YELLOW}正在安装 Python 依赖: requests...${NC}"
        pip3 install requests
    fi
    
    # 检查并安装其他可能需要的工具
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}正在安装 curl...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        fi
    fi
    
    echo -e "${GREEN}依赖检查完成!${NC}"
}

# 下载项目函数
download_project() {
    if command -v git &> /dev/null; then
        git clone https://github.com/eooce/python-xray-argo.git "$PROJECT_DIR_NAME"
    else
        echo -e "${YELLOW}Git未安装，使用wget下载...${NC}"
        wget -q https://github.com/eooce/python-xray-argo/archive/refs/heads/main.zip -O python-xray-argo.zip
        
        if ! command -v unzip &> /dev/null; then
            echo -e "${YELLOW}正在安装 unzip...${NC}"
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y unzip
            elif command -v yum &> /dev/null; then
                sudo yum install -y unzip
            fi
        fi
        
        unzip -q python-xray-argo.zip
        mv python-xray-argo-main "$PROJECT_DIR_NAME"
        rm python-xray-argo.zip
    fi
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR_NAME" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
}

# 自动配置app.py函数
configure_app_auto() {
    echo -e "${BLUE}配置应用参数...${NC}"
    
    # 备份原始文件
    if [ ! -f "app.py.backup" ]; then
        cp app.py app.py.backup
        echo -e "${YELLOW}已备份原始文件为 app.py.backup${NC}"
    fi
    
    # 设置UUID
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID')/" app.py
    
    # 设置节点名称
    sed -i "s/NAME = os.environ.get('NAME', '[^']*')/NAME = os.environ.get('NAME', '$NAME')/" app.py
    
    # 设置服务端口
    sed -i "s/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or [0-9]*)/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or $PORT)/" app.py
    
    # 设置优选IP
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP')/" app.py
    
    # 设置优选端口
    sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT'))/" app.py
    
    # 设置订阅路径
    sed -i "s/SUB_PATH = os.environ.get('SUB_PATH', '[^']*')/SUB_PATH = os.environ.get('SUB_PATH', '$SUB_PATH')/" app.py
    
    # 设置Argo端口
    sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT'))/" app.py
    
    echo -e "${GREEN}应用参数配置完成${NC}"
}

# 启动服务函数
start_service_auto() {
    echo -e "${BLUE}启动服务...${NC}"
    
    # 先清理可能存在的进程
    pkill -f "python3 app.py" > /dev/null 2>&1
    sleep 2
    
    # 启动服务并获取PID[8](@ref)
    python3 app.py > app.log 2>&1 &
    APP_PID=$!
    
    # 验证PID获取成功
    if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
        echo -e "${RED}获取进程PID失败，尝试直接启动${NC}"
        nohup python3 app.py > app.log 2>&1 &
        sleep 2
        APP_PID=$(pgrep -f "python3 app.py" | head -1)
        if [ -z "$APP_PID" ]; then
            echo -e "${RED}服务启动失败，请检查Python环境${NC}"
            echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}服务已在后台启动，PID: $APP_PID${NC}"
    echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"
    
    # 如果设置了HuggingFace保活，启动保活任务
    if [ "$KEEP_ALIVE_HF" = "true" ] && [ -n "$HF_TOKEN" ] && [ -n "$HF_REPO_ID" ]; then
        start_keep_alive_task
    fi
}

# 启动保活任务函数
start_keep_alive_task() {
    echo -e "${BLUE}启动 Hugging Face API 保活任务...${NC}"
    
    # 创建保活任务脚本
    cat > keep_alive_task.sh << EOF
#!/bin/bash
while true; do
    # 尝试 Spaces API
    status_code=\$(curl -s -o /dev/null -w "%{http_code}" --header "Authorization: Bearer $HF_TOKEN" "https://huggingface.co/api/spaces/$HF_REPO_ID")
    if [ "\$status_code" -eq 200 ]; then
        echo "Hugging Face API 保活成功 (Space: $HF_REPO_ID, 状态码: 200) - \$(date '+%Y-%m-%d %H:%M:%S')" > keep_alive_status.log
    else
        # 尝试 Models API
        status_code_model=\$(curl -s -o /dev/null -w "%{http_code}" --header "Authorization: Bearer $HF_TOKEN" "https://huggingface.co/api/models/$HF_REPO_ID")
        if [ "\$status_code_model" -eq 200 ]; then
            echo "Hugging Face API 保活成功 (Model: $HF_REPO_ID, 状态码: 200) - \$(date '+%Y-%m-%d %H:%M:%S')" > keep_alive_status.log
        else
            echo "Hugging Face API 保活失败 (仓库: $HF_REPO_ID, Space API状态: \$status_code, Model API状态: \$status_code_model) - \$(date '+%Y-%m-%d %H:%M:%S')" > keep_alive_status.log
        fi
    fi
    sleep 120
done
EOF
    
    chmod +x keep_alive_task.sh
    
    # 使用nohup后台运行保活任务[8](@ref)
    nohup ./keep_alive_task.sh >/dev/null 2>&1 &
    KEEPALIVE_PID=$!
    echo -e "${GREEN}Hugging Face API 保活任务已启动 (PID: $KEEPALIVE_PID)${NC}"
}

# 保存配置信息函数
save_config_info() {
    echo -e "${BLUE}保存配置信息...${NC}"
    
    SAVE_INFO="========================================
                      节点信息保存                      
========================================

部署时间: $(date)
部署模式: 静默安装
UUID: $UUID
节点名称: $NAME
服务端口: $PORT
优选IP: $CFIP
优选端口: $CFPORT
订阅路径: $SUB_PATH
Argo端口: $ARGO_PORT
HuggingFace保活: $KEEP_ALIVE_HF"

    if [ "$KEEP_ALIVE_HF" = "true" ]; then
        SAVE_INFO="${SAVE_INFO}
HF仓库ID: $HF_REPO_ID"
    fi

    SAVE_INFO="${SAVE_INFO}

=== 管理命令 ===
查看日志: tail -f $(pwd)/app.log
停止服务: kill $APP_PID
重启服务: kill $APP_PID && nohup python3 app.py > app.log 2>&1 &"

    echo "$SAVE_INFO" > "$NODE_INFO_FILE"
    echo -e "${GREEN}配置信息已保存到 $NODE_INFO_FILE${NC}"
}

# 参数检查
if [ "$1" = "-v" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}                      节点信息查看                      ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
    else
        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
    fi
    exit 0
fi

# 静默安装模式
if [ "$1" = "-a" ] || [ "$1" = "--auto" ]; then
    auto_install_mode
fi

# 原有的交互式模式代码保持不变
# ... (这里保留原有的交互式模式代码)

echo -e "${GREEN}脚本执行完成!${NC}"
