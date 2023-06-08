# shrediscaner
Redis SCAN &amp; Batch Cleanup Keys (EXPIRE | UNLINK | DEL)

# Usage
```SHELL
./shrediscaner.sh <Host> <Port> <ACT> <Pattern> [pass]

ACT Options:
  expire  # 设置失效时间
  unlink  # 异步清理
  del     # 同步清理

Example:
  ./shrediscaner.sh 127.0.0.1 6379 DEL "prefix_*" mypass
```
