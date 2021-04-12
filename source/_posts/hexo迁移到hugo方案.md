---
title: hexo 迁移到 hugo 方案
author: YyWang
date: 2021-03-04 15:02:29
tags: hugo
categories: hugo
---

云原生第一步首先要拥抱 go 语言，go 语言第一步首先从迁移博客开始，hugo 是用 golang 实现的静态博客生成工具，给我最大的吸引力是生成静态资源的速度很快，并且是热更新，就是说我修改了文章后不需要重启 hugo 就可以更新博客的状态，这简直太爽了

#### 安装
```
# 安装
brew install hugo
#
Error: hugo: no bottle available!
You can try to install from source with:
  brew install --build-from-source hugo
Please note building from source is unsupported. You will encounter build
failures with some formulae. If you experience any issues please create pull
requests instead of asking for help on Homebrew's GitHub, Twitter or any other
official channels.
# 按照提示重新安装
brew install --build-from-source hugo
# 验证
hugo version 
# 成功
Hugo Static Site Generator v0.80.0/extended darwin/amd64 BuildDate: unknown

```

#### 创建一个网站

```
hugo new site blog-hugo
```

会在hugo目录下创建一个 blog-hugo 的文件夹，目录结构为

```
.
├── archetypes
│   └── default.md
├── config.toml
├── content
├── data
├── layouts
├── static
└── themes
```

#### 添加主题

我选用LoveIt的主题

```
cd blog-hugo/themes/
git clone https://github.com/dillonzq/LoveIt.git
# 复制 exampleSite 中的文件到 blog-hugo 目录下
cp -rf LoveIt/exampleSite/ ../../
# 修改主题位置
vim config.toml
# 修改 themesDir = "themes/"
# 启动 必须要在创建的 Site 目录下，否有要 -s=xxx 指定目录
hugo server
```
**踩坑! 如果提示保持 too many request from balabala ... 需要在config.toml中添加配置 ignoreErrors = ["error-remote-getjson"]**

#### 迁移博客

1. 头信息修改，hexo中的头信息我是这样写的

```
title: 2020 又是起起落落落落的一年 
author: YyWang 
tags: 生活杂谈 
categories: 生活杂谈
date: 2021-02-08 17:57:12
---
```
hugo 中头信息为这样

```
---
title: 2020 又是起起落落落落的一年
author: YyWang
authorLink: http://www.yywang.top #新增
date: 2021-02-08T17:57:12+08:00 #修改格式
lastmod: 2021-02-08T17:57:12+08:00 #新增
draft: false #新增
tags: ["生活杂谈"] #修改格式
categories: ["生活杂谈"] #修改格式
featuredImagePreview: #新增
---
```
当然是写代码修改啦，因为hexo中的文章都没以 --- 开头，所以我就统一这个格式处理了，(刚学golang写的很糙😬)，处理代码如下

```
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main(){
	// 获取文件夹中所有文件
	pathPrefix := "${pathPrefix}"
	files := getAllFiles(pathPrefix)
	for _,f := range files {
		// 先读文件，在写文件
		err := writeFile(f, readFile(f))
		if err != nil {
			fmt.Printf("write error %v", err)
		}
	}
}

func readFile(filepath string) []byte{
	file, _ := os.OpenFile(filepath, os.O_RDONLY, 0644)
	defer file.Close()

	reader := bufio.NewReader(file)
	buffer := make([]byte, 0)

	var title, author, tags, categories, date string

	appendFlag := false
	for {
		line, _, err := reader.ReadLine()
		if err != nil {
			if err == io.EOF {
				appendPre := make([]byte, 0)
				appendPre = append(appendPre, "---\n"...)
				appendPre = append(appendPre, "title: " + title +"\n"...)
				appendPre = append(appendPre, "author: " + author +"\n"...)
				appendPre = append(appendPre, "authorLink: http://www.yywang.top\n"...)
				appendPre = append(appendPre, "date: " + date +"\n"...)
				appendPre = append(appendPre, "lastmod: " + date +"\n"...)
				appendPre = append(appendPre, "draft: false\n"...)
				appendPre = append(appendPre, "tags: [\""+tags+"\"]\n"...)
				appendPre = append(appendPre, "categories: [\""+categories+"\"]\n"...)
				appendPre = append(appendPre, "featuredImagePreview: \n"...)
				appendPre = append(appendPre, "---\n"...)
				return  append(appendPre, buffer...)
			}
		}
		lineStr := string(line[:])
		if strings.EqualFold(lineStr, "---") {
			appendFlag = true
			continue
		}

		if appendFlag {
			// copy
			buffer = append(buffer, line...)
			buffer = append(buffer, "\n"...)
		} else {
			i := strings.Index(lineStr, ":")
			if i > 0 {
				k := lineStr[0:i]
				v := strings.TrimSpace(lineStr[i+1:])
				switch k {
				case "title":
					title = v
				case "author":
					author = v
				case "tags":
					tags = v
				case "categories":
					categories = v
				case "date":
					date = transDataFormat(v, "2006-01-02 15:04:05", "2006-01-02T15:04:05+08:00")
				default:
					fmt.Println("error switch " + k)
				}
			} else {
				fmt.Println("split error " + lineStr)
			}
		}
	}

}

func getAllFiles(path string) []string {
	files := make([]string, 0)
	err := filepath.Walk(path, func(path string, f os.FileInfo, err error) error{
		if f.IsDir() {
			return nil
		}
		files = append(files, path)
		return  nil
	})
	if err != nil {
		fmt.Printf("walk file path err info is %v", err)
	}
	return files
}

func transDataFormat(timeStr string, oldFormat string, newFormat string) string {
	date, _ := time.Parse(oldFormat, timeStr)
	return date.Format(newFormat)
}

func writeFile(filePath string, content []byte) error {
	f, err := os.OpenFile(filePath, os.O_WRONLY|os.O_TRUNC, 0600)
	defer f.Close()
	if err != nil {
		return err
	}
	writer := bufio.NewWriter(f)
	_, err = writer.Write(content)
	if err != nil {
		return err
	}
	err = writer.Flush()
	if err != nil {
		fmt.Printf("flush error %v", err)
	}
	return nil
}

```

然后将新修改的文件移动到 blog-hugo/content/posts/ 目录下

2. 将文章中引用的图片移动到 blog-hugo/assets/images/ 目录下
3. 如果在文章中还引用过其他文章，url会失效，手动修改下或者参考[这里，查看文件链接](https://liujiacai.net/blog/2020/12/05/hexo-to-hugo/)处理

**到这里博客基本上迁移完毕了，附一个初步的效果图，后面还需进一步美化和优化，等上线了再切负载替换hexo**

![hugodemodemo](/images/hugodemo.png)

#### TODO

* 打包docker镜像，以docker的方式部署，nginx切换负载
* 备份hugo博客的方案
* 参考[这里](https://lewky.cn/tags/hugo/)做增强
* 换一套头像，大图小图啥的，参考主题中exampleSite里的post介绍，[这个网站生成套图](https://realfavicongenerator.net/)
* 更换评论系统插件[waline](https://waline.js.org/)
