# serv00-keepalive

众所周知，**serv00** 是用于搭建个人博客的服务器。然而，**serv00** 经常重启，导致服务中断。本项目将展示如何搭建一个服务保活的 Node.js 网页，你可以根据自己的需求进行更改。

在下文示例中，用户名为 **abc**，服务器为 **s15**。请将文中所有的 `abc` 和 `panel15` 替换为你自己的用户名和面板名。

---

## step 1: 在 serv00 上创建一个 Node.js 网页

1. 登录面板 [panel15.serv00.com](http://panel15.serv00.com)，如图所示点击删除页面：
   
   ![image](https://github.com/user-attachments/assets/3bba8939-3284-4d75-9f3f-4a068655100d)  
   ![image](https://github.com/user-attachments/assets/66d6b79c-2e5a-4d66-8cb8-1ffda62a158d)

2. 如图点击新建一个 Node.js 页面：

   ![image](https://github.com/user-attachments/assets/f9fad0e3-00b3-4692-977b-13bee2e4b5ad)

3. 为该页面添加 SSL 证书（可以跳过这一步，非必须）：

   ![image](https://github.com/user-attachments/assets/d519549e-a8ea-480f-9bcb-ecfc7379240c)  
   ![image](https://github.com/user-attachments/assets/ee0eea93-d958-469c-9b6b-34510a0c2e1e)  
   ![image](https://github.com/user-attachments/assets/3a41e1d1-d55b-4273-aed1-12813f6a348e)  
   ![image](https://github.com/user-attachments/assets/ff049f3a-6c04-4155-b69d-ceeadde3fea7)

---

## step 2: 安装依赖环境

登录到 **serv00** 服务器，并执行以下命令安装必要的依赖：

```bash
npm install dotenv basic-auth express
```

---

## step 3: 安装保活网页

1. 登录到 **serv00** 服务器后，执行命令切换到目标目录：

   ```bash
   cd ~/domains/abc.serv00.net/public_nodejs
   ```

2. 复制以下内容到剪切板：

```js
require('dotenv').config();
const express = require("express");
const { exec } = require('child_process');
const app = express();

app.use(express.json());

// 保留 /info 页面路由
app.get("/info", function (req, res) {
    // 在访问 /info 时执行保活命令
    // const commandToRun = "cd ~/serv00-play/singbox/ && bash start.sh && cd ~/.nezha-dashboard/ && bash start.sh&";
    const commandToRun = "cd ~/serv00-play/singbox/ && bash start.sh";
    exec(commandToRun, function (err, stdout, stderr) {
        if (err) {
            console.log("命令执行错误: " + err);
            res.status(500).send("服务器错误");
            return;
        }
        if (stderr) {
            console.log("命令执行标准错误输出: " + stderr);
        }
        console.log("命令执行成功:\n" + stdout);
    });

    res.type("html").send("<pre>你好啊</pre>");
});

// 只允许访问 /info 页面，其他页面返回 404
app.use((req, res, next) => {
    if (req.path === '/info') {
        return next(); // 如果是 /info 页面，继续处理后续路由
    }
    res.status(404).send('页面未找到');
});

app.listen(3000, () => {
    console.log("服务器已启动，监听端口 3000");
});
```

3. 使用命令创建 `app.js` 文件：

   ```bash
   nano app.js
   ```

4. 进入 `nano` 编辑器后，右键粘贴剪切板的内容，使用 `Ctrl+S` 保存并 `Ctrl+X` 退出。

5. 现在，访问 `https://abc.serv00.net/info/`。

6. 如果看到 `你好啊`，说明保活页面部署成功。

---

## step 4: 自定义保活命令

7. 根据自己的需求，你可以修改 `app.js` 中的这一行：

   ```js
   const commandToRun = "cd ~/serv00-play/singbox/ && bash start.sh";
   ```

   这样每次你访问 `https://abc.serv00.net/info/` 时，都会执行一次你自定义的保活命令。

---

## step 5: 最后

如果有更复杂的需求或者问题，可以发 issue.
部署完以后，看看这个文件：[keep.sh](https://github.com/QWsudo/serv00-keepalive/blob/main/keep.sh)。你可以在软路由，你的 vps，甚至 serv00 之间实现全自动保活。
