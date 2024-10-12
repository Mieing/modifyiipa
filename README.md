# modifyiipa

### 安装
安装[modifyiipa]()，在终端运行
```
modifyiipa
```


##### 用法
```
modifyiipa ipa_path param
```
##### 参数
```
-id newBundleID                 修改 bundle id
-u  enable RemoveURLSchemes     Remove url schemes
```

##### 一个例子
```
modifyiipa /var/mobile/Documents/modifyiipa.ipa -id cn.modifyiipa.st -u
