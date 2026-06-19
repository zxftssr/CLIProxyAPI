# 43.156.46.247 部署记录

更新时间：2026-06-19 08:47 CST

本文记录 `43.156.46.247` 上 CLIProxyAPI 的部署状态、访问方式、服务配置和常用运维命令。文档不包含 SSH 密码、API key、Vertex service account 私钥等敏感信息。

## 概览

- 服务器：腾讯云轻量应用服务器
- 公网 IPv4：`43.156.46.247`
- 内网 IPv4：`10.3.0.11`
- 主机名：`VM-0-11-opencloudos`
- 系统：`OpenCloudOS 9.4`
- 内核：`Linux 6.6.117-45.1.oc9.x86_64 x86_64 GNU/Linux`
- 对外 API Base URL：`https://www.xfzh.online/v1`
- 后端服务目录：`/opt/cliproxyapi`
- 后端监听：`127.0.0.1:8317`
- HTTPS 入口：Caddy 监听公网 `80` 和 `443`

## 域名与证书

- 域名：`www.xfzh.online`
- DNS 服务商：DNSPod
- 解析记录：`www.xfzh.online A 43.156.46.247`
- TTL：`600`
- 根域名 `xfzh.online` 未改动，仍保留原有用途。
- HTTPS 证书：由 Caddy 自动通过 Let's Encrypt 申请和续期。
- HTTP 行为：`http://www.xfzh.online/...` 自动 `308` 跳转到 `https://www.xfzh.online/...`。

## 访问方式

客户端应使用：

```text
https://www.xfzh.online/v1
```

鉴权方式保持 CLIProxyAPI 原配置：

```text
Authorization: Bearer <config.yaml 中配置的 api key>
```

示例请求：

```bash
curl https://www.xfzh.online/v1/models \
  -H "Authorization: Bearer <api key>"
```

未携带 API key 时，`/v1/models` 返回 `401` 属于正常行为，表示 HTTPS 入口已通但鉴权失败。

## 文件布局

```text
/opt/cliproxyapi/
├── cli-proxy-api
├── config.yaml
└── auths/
    └── vertex-vertex-project-5f7266c5-c8d5-4d6d-b9e.json
```

关键配置：

```yaml
host: "127.0.0.1"
port: 8317
```

Vertex 凭证文件使用来自 `my-blog` 项目 `application.yml` 实际引用的 service account JSON，项目 ID 为 `project-5f7266c5-c8d5-4d6d-b9e`，区域为 `global`。

## Caddy 配置

配置文件：`/etc/caddy/Caddyfile`

```caddyfile
www.xfzh.online {
	encode gzip
	reverse_proxy 127.0.0.1:8317
}
```

作用：

- 监听公网 `80` 和 `443`
- 自动签发和续期 HTTPS 证书
- 自动将 HTTP 跳转到 HTTPS
- 将 HTTPS 请求反向代理到本机 CLIProxyAPI：`127.0.0.1:8317`

## systemd 服务

### CLIProxyAPI

服务名：`cliproxyapi.service`

服务文件：`/etc/systemd/system/cliproxyapi.service`

```ini
[Unit]
Description=CLIProxyAPI Vertex proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/cliproxyapi
ExecStartPre=/bin/sh -c '/usr/sbin/iptables -C INPUT -p tcp --dport 8317 -j ACCEPT 2>/dev/null || /usr/sbin/iptables -I INPUT 1 -p tcp --dport 8317 -j ACCEPT'
ExecStart=/opt/cliproxyapi/cli-proxy-api --config /opt/cliproxyapi/config.yaml --local-model
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

当前状态：

```text
active
enabled
```

说明：虽然本机 iptables 中仍有 `8317` 放行规则，但 CLIProxyAPI 只监听 `127.0.0.1:8317`，腾讯云防火墙也已删除公网 `8317` 入口，因此公网不能直连后端端口。

### Caddy

服务名：`caddy`

当前状态：

```text
active
enabled
```

### 本机防火墙辅助服务

服务名：`cliproxy-firewall.service`

服务文件：`/etc/systemd/system/cliproxy-firewall.service`

```ini
[Unit]
Description=CLIProxyAPI public HTTPS firewall rules
Before=caddy.service
After=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cliproxy-firewall.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

当前状态：

```text
active
enabled
```

作用：确保服务器系统防火墙放行 `80` 和 `443`。

## 端口与防火墙

当前监听：

```text
127.0.0.1:8317  cli-proxy-api
*:443           caddy
*:80            caddy
```

腾讯云轻量防火墙规则：

- `TCP 443,80`：允许，备注 `HTTPS-Caddy`
- `TCP 22`：允许，用于 SSH
- `ICMP ALL`：允许，用于 ping
- `TCP 18789`：保留原有规则
- `TCP 8317`：已删除公网入口

本机 iptables 当前包含：

```text
ACCEPT tcp dpt:443
ACCEPT tcp dpt:80
ACCEPT tcp dpt:8317
```

`8317` 仅用于本机 Caddy 反向代理到后端，公网不可直连。

## 已验证结果

2026-06-19 08:47 CST 的验证结果：

```text
www.xfzh.online -> 43.156.46.247
HTTPS /v1/models -> HTTP 200
TLS verification -> 0
Vertex model count -> 16
caddy -> active / enabled
cliproxyapi.service -> active / enabled
cliproxy-firewall.service -> active / enabled
```

已暴露的 Vertex 模型：

```text
vertex/gemini-2.5-flash
vertex/gemini-2.5-flash-image
vertex/gemini-2.5-flash-lite
vertex/gemini-2.5-pro
vertex/gemini-3-flash-preview
vertex/gemini-3-pro-image-preview
vertex/gemini-3-pro-preview
vertex/gemini-3.1-flash-image-preview
vertex/gemini-3.1-flash-lite-preview
vertex/gemini-3.1-pro-preview
vertex/gemini-3.5-flash
vertex/imagen-3.0-fast-generate-001
vertex/imagen-3.0-generate-002
vertex/imagen-4.0-fast-generate-001
vertex/imagen-4.0-generate-001
vertex/imagen-4.0-ultra-generate-001
```

## 常用运维命令

查看服务状态：

```bash
systemctl status cliproxyapi.service --no-pager -l
systemctl status caddy --no-pager -l
systemctl status cliproxy-firewall.service --no-pager -l
```

查看日志：

```bash
journalctl -u cliproxyapi.service -n 100 --no-pager
journalctl -u caddy -n 100 --no-pager
```

重启服务：

```bash
systemctl restart cliproxyapi.service
systemctl restart caddy
```

检查监听端口：

```bash
ss -ltnp | grep -E ':(80|443|8317)'
```

检查 DNS：

```bash
getent ahostsv4 www.xfzh.online
```

检查 HTTPS 入口：

```bash
curl -I https://www.xfzh.online/v1/models
```

带鉴权检查模型列表：

```bash
curl https://www.xfzh.online/v1/models \
  -H "Authorization: Bearer <api key>"
```

检查 HTTP 到 HTTPS 跳转：

```bash
curl -I http://www.xfzh.online/v1/models
```

## 更新部署

如果要更新 CLIProxyAPI 二进制：

1. 在本地构建 Linux amd64 二进制。
2. 上传覆盖 `/opt/cliproxyapi/cli-proxy-api`。
3. 确保文件可执行。
4. 重启服务。

示例：

```bash
systemctl restart cliproxyapi.service
systemctl status cliproxyapi.service --no-pager -l
```

## 安全注意事项

- 不要把 `/opt/cliproxyapi/config.yaml` 中的 API key 写入文档或提交到公开仓库。
- 不要公开 `/opt/cliproxyapi/auths/` 下的 Vertex service account JSON。
- 对外只应暴露 `80/443`，后端 `8317` 保持本机监听。
- 如需进一步收紧访问，可在 Caddy 层或腾讯云防火墙中限制来源 IP。
