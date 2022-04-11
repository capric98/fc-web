# fc-web

一个适合部署在阿里云函数计算上的nginx & php docker镜像。

## 使用方法

有以下两种食用方法，可根据自己的喜好选择。

### 手动上传

比较适合喜欢直观的小伙伴，直接clone本项目，并从Dockerfile生成镜像，然后将镜像推送到阿里云容器镜像服务（操作都可以通过Docker的GUI、阿里云控制台提示完成，几乎不需要敲命令）。

镜像上传后得到一个仓库地址，接下来就可以拿着这个仓库地址去阿里云函数计算控制台去新建一个Custom Container函数了。

请注意，默认设置下，函数计算控制台的端口、NAS设置需要和repo内的Dockerfile保持一致：

```bash
Port=9000
UserID=10003
GroupIP=10003
NASDir="/home/app"
```

另外请注意，函数需要和镜像在同一地区。

### Actions持续集成(雾)

和手动上传类似，需要先去控制台新建好对应函数，只不过新建的时候可能还没有镜像，此时可以使用官方提供的一些示例项目来创建函数，并设置好对应的NAS、VPC、安全组。

创建成功后，通过控制台导出函数配置，会下载一个`s.yml`文件，这个文件可以在Serverless Devs工具中完整描述一个函数服务。

接下来，请参考[s_example.yaml](https://gist.github.com/capric98/49d92bd0780fc636e92f972636dee211)对配置文件做一些修改（主要是需要将`access`改成`'actions'`，另外需要将`runtime`改成`custom-container`），并将它上传到一个可以提供外链的地方（比如gist private repo），接下来，fork本项目，并在fork项目中开启actions，并设置以下Actions Secrets：

```bash
ACCOUNT_ID="{{ 主账号ID }}"
ACCESS_KEY_ID="{{ 主账号AccessKeyID }}"
ACCESS_KEY_SECRET="{{ 主账号AccessKeySecret }}"
TEMPLATE_URL="{{ 外链地址 }}"
```

接下来，请新建一个名叫`deploy`的分支，之后所有推送到deploy的提交，都会自动调用actions，根据`{{ env.TEMPLATE_URL }}`对应文件描述的函数服务，自动生成、部署对应的函数。

你可以在GitHub的Actions查看部署情况，当部署成功后，你可以像手动上传完成后一样，在阿里云函数计算的控制台里继续去设置自定义域名、CDN加速等等……

## 函数运行

当函数每次运行的时候，都会首先检查NAS挂载点，并自动新建必须的文件夹。

仓库中`nas`文件夹内的文件，将会被自动同步到nas上（如果对应文件已经存在，将会跳过同步，同步是为了保证函数每次都能正常启动，因为TinyFileManager将会是少有的管理NAS内文件比较方便的手段——Serverless Devs又慢又不好用……）

如果冷启动的时候，nginx或php的配置文件检查不通过，`bootstrap`将会将对应nginx或php的配置目录重命名成一个带时间的名称，并将相应配置文件夹恢复成项目`nas`下对应的版本。

**请注意，该行为是为了保证TinyFileManager会启动成功，但重置后可能导致业务离线和未配置身份验证的tfm暴露，请多加小心！**

## 部署完成后

默认可以通过`/manage/tfm.php`来管理NAS挂载目录内的文件。

**请注意，自带的TineFileManager关闭了身份验证功能，这可能会导致严重的安全问题，请在完成第一次登陆后，立即编辑tfm.php开启验证并修改用户密码！**

### 配置文件

假设NAS默认挂载在`/home/app`

* `/home/app/conf.d/nginx`
  
  * `*.conf`：被`nginx.conf`中的`http`模块加载：
    
    ```nginx
    # ...
    http {
        # ...
        include /home/app/conf.d/nginx/*.conf;
    }
    ```

* `/home/app/conf.d/php`
  
  * `*.conf`：被`php-fpm.d/www.conf`加载
  
  * `ini/*`：被`php.ini`加载

### Nginx与PHP的动态重载

假设NAS默认挂载在`/home/app`

### Nginx

添加或修改配置文件后，创建一个`/home/app/conf.d/nginx/RELOAD`空文件，`bootstrap`监测到后将会尝试reload nginx，如果配置文件检查出错，将会输出错误信息到`/home/app/conf.d/nginx/RELOAD.FAIL`

### PHP

添加或修改配置文件后，创建一个`/home/app/conf.d/php/RELOAD`空文件，`bootstrap`监测到后将会尝试reload PHP，如果配置文件检查出错，将会输出错误信息到`/home/app/conf.d/php/RELOAD.FAIL`