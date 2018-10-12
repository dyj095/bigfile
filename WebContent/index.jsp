<%@ page language="java" contentType="text/html; charset=UTF-8"
	pageEncoding="UTF-8"%>

<%
	String web_path = request.getContextPath();
%>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="utf-8">
		<title>大文件上传Demo</title>
		<link href="plugins/bootstrap/css/bootstrap.min.css" rel="stylesheet">
		<link href="plugins/bootstrap/css/bootstrap-theme.min.css" rel="stylesheet">
		<script type="text/javascript" src="js/jquery-3.1.1.js"></script>
		<script type="text/javascript" src="plugins/bootstrap/js/bootstrap.min.js"></script>
	</head>
	<body>
		<input type="file" multiple=true onchange="doSomething(this.files)"/>
		<input id="uploadBtn" type="button"  value="上传"  onclick="doUpload()"/>&nbsp;
        <progress value="0" max="10" id="prouploadfile"></progress>  
        <span id="persent">0%</span>  
		<script type="text/javascript">
			//上传进度  
	        var pro = document.getElementById('prouploadfile');  
	        var persent = document.getElementById('persent');  
			var doSomething = function(files){
				console.log(files);
			}
			var quence = new Array();// 待上传的文件队列，包含切块的文件
			/**
			 * 用户选择文件之后的响应函数，将文件信息展示在页面，同时对大文件的切块大小、块的起止进行计算、入列等
			 */
			function showFileList(files) {
				if (!files) {
					return;
				}

				var chunkSize = 5 * 1024 * 1024; // 切块的阀值：5M
				$(files).each(function(idx, e) {
							// 展示文件列表，略......

							if (e.size > chunkSize) {// 文件大于阀值，进行切块
								// 切块发送
								var chunks = Math.max(Math.floor(fileSize / chunkSize), 1)
										+ 1;// 分割块数
								for (var i = 0; i < chunks; i++) {
									var startIdx = i * chunkSize;// 块的起始位置
									var endIdx = startIdx + chunkSize;// 块的结束位置
									if (endIdx > fileSize) {
										endIdx = fileSize;
									}
									var lastChunk = false;
									if (i == (chunks - 1)) {
										lastChunk = true;
									}
									// 封装成一个task，入列
									var task = {
										file : e,
										uuid : uuid,// 避免文件的重名导致服务端无法定位文件，需要给每个文件生产一个UUID
										chunked : true,
										startIdx : startIdx,
										endIdx : endIdx,
										currChunk : i,
										totalChunk : chunks
									}
									quence.push(task);

								}
							} else {// 文件小于阀值

								var task = {
									file : e,
									uuid : uuid,
									chunked : false
								}
								quence.push(task);

							}
						});
			}

			/**
			 * 上传器，绑定一个XMLHttpRequest对象，处理分配给其的上传任务
			 */
			function Uploader(name) {
				this.url = ""; // 服务端处理url
				this.req = new XMLHttpRequest();
				this.tasks; // 任务队列
				this.taskIdx = 0; // 当前处理的tasks的下标
				this.name = name;
				this.status = 0; // 状态，0：初始；1：所有任务成功；2：异常

				// 上传 动作
				this.upload = function(uploader) {
					this.req.responseType = "json";

					// 注册load事件（即一次异步请求收到服务端的响应）
					this.req.addEventListener("load", function() {
								// 更新对应的进度条
								progressUpdate(this.response.uuid, this.response.fileSize);
								// 从任务队列中取一个再次发送
								var task = uploader.tasks[uploader.taskIdx];
								if (task) {
									console.log(uploader.name + "：当前执行的任务编号："
											+ uploader.taskIdx);
									this.open("POST", uploader.url);
									this.send(uploader.buildFormData(task));
									uploader.taskIdx++;
								} else {
									console.log("处理完毕");
									uploader.status = 1;
								}
							});

					// 处理第一个
					var task = this.tasks[this.taskIdx];
					if (task) {
						console.log(uploader.name + "：当前执行的任务编号：" + this.taskIdx);
						this.req.open("POST", this.url);
						this.req.send(this.buildFormData(task));
						this.taskIdx++;
					} else {
						uploader.status = 1;
					}
				}

				// 提交任务
				this.submit = function(tasks) {
					this.tasks = tasks;
				}

				// 构造表单数据
				this.buildFormData = function(task) {
					var file = task.file;
					var formData = new FormData();
					formData.append("fileName", file.name);
					formData.append("fileSize", file.size);
					formData.append("uuid", task.uuid);
					var chunked = task.chunked;
					if (chunked) {// 分块
						formData.append("chunked", task.chunked);
						formData.append("data", file.slice(task.startIdx, task.endIdx));// 截取文件块
						formData.append("currChunk", task.currChunk);
						formData.append("totalChunk", task.totalChunk);
					} else {
						formData.append("data", file);
					}
					return formData;
				}

			}

			/**
			 * 用户点击“上传”按钮
			 */
			function doUpload() {

				// 创建4个Uploader上传器（4条线程）
				var uploader0 = new Uploader("uploader0");
				var task0 = new Array();

				var uploader1 = new Uploader("uploader1");
				var task1 = new Array();

				var uploader2 = new Uploader("uploader2");
				var task2 = new Array();

				var uploader3 = new Uploader("uploader3");
				var task3 = new Array();

				// 将文件列表取模hash，分配给4个上传器
				for (var i = 0; i < quence.length; i++) {
					if (i % 4 == 0) {
						task0.push(quence[i]);
					} else if (i % 4 == 1) {
						task1.push(quence[i]);
					} else if (i % 4 == 2) {
						task2.push(quence[i]);
					} else if (i % 4 == 3) {
						task3.push(quence[i]);
					}
				}
				// 提交任务，启动线程上传
				uploader0.submit(task0);
				uploader0.upload(uploader0);
				uploader1.submit(task1);
				uploader1.upload(uploader1);
				uploader2.submit(task2);
				uploader2.upload(uploader2);
				uploader3.submit(task3);
				uploader3.upload(uploader3);

				// 注册一个定时任务，每2秒监控文件是否都上传完毕
				uploadCompleteMonitor = setInterval("uploadComplete()", 2000);
			}
		</script>
	</body>
</html>