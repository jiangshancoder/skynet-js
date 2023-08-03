# skynet-js





一个 websocket + proto3 + mongodb的项目演示

后续可能添加tcp和sproto







skynet编译自行百度

外面是xmake（最下面有xmake安装命令）

`xmake --root`



lua-crypt库是扒的cfadmin里面的加密库

lua-lfs找不到在哪里扒的了





对原skynet有一点改动

`skynet\lualib\skynet\db\mongo.lua`

中，增加一个函数如下：

```lua
function mongo_collection:getIndexes()
	local res = self.database:runCommand("listIndexes",self.name)
	if res and res.ok == 1 then
		return res.cursor.firstBatch
	else
		return
	end
end
```







**xmake安装如下：**

```
wget https://xmake.io/shget.text -O - | bash
```

可能会报错

```
error while loading shared libraries: libatomic.so.1: cannot open shared object file:

xmake: error while loading shared libraries: libatomic.so.1: wrong ELF class: ELFCLASS32
```



**对于Centos8，请以根用户root运行下面命令**：

```
cd /etc/yum.repos.d/

wget https://download.opensuse.org/repositories/home:aevseev:devel/CentOS8/home:aevseev:devel.repo

yum install libatomic1
```



**对于 CentOS7，请以根用户 Root 运行下面命令**：

```
cd /etc/yum.repos.d/

wget https://download.opensuse.org/repositories/home:aevseev:devel/CentOS7/home:aevseev:devel.repo

yum install libatomic1
```



**对于 Ubuntu，请以根用户 Root 运行下面命令**：

参考
https://zhuanlan.zhihu.com/p/473205876


```

sudo add-apt-repository ppa:xmake-io/xmake

sudo apt update

sudo apt install xmake

安装成功后，运行

xmake --version

```



