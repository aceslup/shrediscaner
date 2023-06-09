# shrediscaner
Redis SCAN &amp; Batch Cleanup Keys (EXPIRE | UNLINK | DEL)

# Support
- Redis 7
- Redis 6
- Redis 5

# Usage
```SHELL
./shrediscaner.sh <Host> <Port> <ACT> <Pattern> [pass]

ACT Options:
  expire  # 设置失效时间 (1-9s随机)
  unlink  # 异步清理
  del     # 同步清理

Example:
  ./shrediscaner.sh 127.0.0.1 6379 DEL "prefix_*" mypass
```
