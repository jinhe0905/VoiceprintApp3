/**
 * 声纹验证页面交互逻辑
 * 包含声纹验证、语音命令和车门控制功能
 */

document.addEventListener('DOMContentLoaded', function() {
    // 初始化页面元素
    initPageElements();
    
    // 初始化选项卡切换
    initTabs();
    
    // 初始化声纹验证面板
    initVoiceprintPanel();
    
    // 初始化语音命令面板
    initCommandPanel();
    
    // 初始化车门控制面板
    initDoorPanel();
    
    // 初始化侧边栏折叠功能
    initSidebar();
    
    // 初始化音频可视化
    initAudioVisualizer();
});

// 初始化页面元素引用
function initPageElements() {
    // 通用页面元素
    window.elements = {
        // 声纹验证面板元素
        voiceprintPanel: document.getElementById('voiceprint-panel'),
        startRecording: document.getElementById('startRecording'),
        stopRecording: document.getElementById('stopRecording'),
        verifyVoiceprint: document.getElementById('verifyVoiceprint'),
        statusMessage: document.getElementById('status-message'),
        resultMessage: document.getElementById('result-message'),
        voiceprintReport: document.getElementById('voiceprint-report'),
        livenessCheck: document.getElementById('liveness-check'),
        voiceprintMatch: document.getElementById('voiceprint-match'),
        recognizedCommand: document.getElementById('recognized-command'),
        commandConfidence: document.getElementById('command-confidence'),
        
        // 语音命令面板元素
        commandPanel: document.getElementById('command-panel'),
        startCommandRecording: document.getElementById('startCommandRecording'),
        stopCommandRecording: document.getElementById('stopCommandRecording'),
        commandStatusMessage: document.getElementById('command-status-message'),
        commandResultMessage: document.getElementById('command-result-message'),
        
        // 车门控制面板元素
        doorPanel: document.getElementById('door-panel'),
        vehicleSelect: document.getElementById('vehicle-select'),
        doorStatus: document.getElementById('door-status'),
        autoLockInfo: document.getElementById('auto-lock-info'),
        unlockDoor: document.getElementById('unlock-door'),
        lockDoor: document.getElementById('lock-door'),
        trunkBtn: document.getElementById('trunk-btn'),
        windowBtn: document.getElementById('window-btn'),
        
        // 音频可视化元素
        visualizer: document.getElementById('visualizer'),
        commandVisualizer: document.getElementById('command-visualizer')
    };
    
    // 初始化选项卡元素
    window.tabs = document.querySelectorAll('.verify-tab');
    window.panels = document.querySelectorAll('.verify-panel');
}

// 初始化选项卡切换功能
function initTabs() {
    window.tabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // 移除所有选项卡的活动状态
            window.tabs.forEach(t => t.classList.remove('active'));
            // 添加当前选项卡的活动状态
            this.classList.add('active');
            
            // 隐藏所有面板
            window.panels.forEach(panel => panel.classList.remove('active'));
            
            // 显示目标面板
            const targetPanel = document.getElementById(this.dataset.target);
            if (targetPanel) {
                targetPanel.classList.add('active');
            }
        });
    });
}

// 初始化声纹验证面板
function initVoiceprintPanel() {
    const { startRecording, stopRecording, verifyVoiceprint, statusMessage } = window.elements;
    
    // 声纹分析器实例
    const voiceprintAnalyzer = new VoiceprintAnalyzer();
    
    // 录音实例
    const audioRecorder = new AudioRecorder(window.elements.visualizer);
    
    // 录音状态
    let isRecording = false;
    let recordedAudio = null;
    
    // 提前初始化录音设备
    audioRecorder.init().then(success => {
        if (success) {
            console.log('录音设备初始化成功');
            statusMessage.textContent = '麦克风就绪，点击"开始录音"进行声纹录制。';
        } else {
            console.error('录音设备初始化失败');
            statusMessage.textContent = '麦克风初始化失败，请检查权限设置。';
            startRecording.disabled = true;
        }
    });
    
    // 开始录音按钮点击事件
    startRecording.addEventListener('click', function() {
        // 重置UI状态
        resetVoiceprintUI();
        
        // 开始录音
        audioRecorder.startRecording();
        
        // 更新UI状态
        isRecording = true;
        startRecording.disabled = true;
        stopRecording.disabled = false;
        verifyVoiceprint.disabled = true;
        statusMessage.textContent = '正在录音，请朗读屏幕上的文字...';
        
        // 开始音频可视化
        startVisualization(window.elements.visualizer);
    });
    
    // 停止录音按钮点击事件
    stopRecording.addEventListener('click', function() {
        if (!isRecording) return;
        
        // 停止录音
        audioRecorder.stopRecording()
            .then(audio => {
                // 保存录制的音频
                recordedAudio = audio;
                
                // 更新UI状态
                isRecording = false;
                startRecording.disabled = false;
                stopRecording.disabled = true;
                verifyVoiceprint.disabled = false;
                statusMessage.textContent = '录音已完成，请点击"验证身份"按钮进行验证。';
                
                // 停止音频可视化
                stopVisualization(window.elements.visualizer);
                
                // 创建音频预览元素
                const audioPreview = document.createElement('audio');
                audioPreview.controls = true;
                audioPreview.src = URL.createObjectURL(audio);
                audioPreview.style.width = '100%';
                audioPreview.style.marginTop = '10px';
                
                // 移除旧的预览元素
                const oldPreview = document.getElementById('audio-preview');
                if (oldPreview) {
                    oldPreview.remove();
                }
                
                // 添加新的预览元素
                audioPreview.id = 'audio-preview';
                window.elements.voiceprintPanel.appendChild(audioPreview);
            })
            .catch(error => {
                console.error('停止录音失败:', error);
                statusMessage.textContent = '停止录音失败: ' + error.message;
            });
    });
    
    // 验证声纹按钮点击事件
    verifyVoiceprint.addEventListener('click', function() {
        if (!recordedAudio) {
            statusMessage.textContent = '没有可用的录音数据，请先录音。';
            return;
        }
        
        // 显示正在处理消息
        statusMessage.textContent = '正在验证声纹，请稍候...';
        verifyVoiceprint.disabled = true;
        
        // 这里使用模拟数据进行演示
        // 在实际应用中，应该将录音数据发送到服务器进行分析
        setTimeout(() => {
            const result = {
                success: true,
                similarity: 0.85,
                liveness: true,
                recognizedCommand: "打开车门",
                commandConfidence: 0.92,
                securityDetails: {
                    uniqueness: 85,
                    stability: 92,
                    clarity: 78
                }
            };
            
            // 处理验证结果
            handleVerificationResult(result);
        }, 1500);
    });
}

// 处理声纹验证结果
function handleVerificationResult(result) {
    const { 
        resultMessage, voiceprintReport, statusMessage, 
        verifyVoiceprint, livenessCheck, voiceprintMatch,
        recognizedCommand, commandConfidence
    } = window.elements;
    
    // 更新验证状态
    verifyVoiceprint.disabled = false;
    
    if (result.success) {
        // 验证成功
        showResultMessage('success', '身份验证成功! 您的声纹已确认。');
        
        // 更新安全检查状态
        updateSecurityCheck(livenessCheck, result.liveness);
        updateSecurityCheck(voiceprintMatch, true);
        
        // 更新命令识别结果
        if (result.recognizedCommand) {
            recognizedCommand.textContent = result.recognizedCommand;
            commandConfidence.textContent = parseInt(result.commandConfidence * 100) + '%';
        }
        
        // 显示声纹质量报告
        showVoiceprintReport(result.securityDetails);
        
        // 自动切换到车门控制面板
        setTimeout(() => {
            // 自动切换到车门控制选项卡
            switchToTab('door-panel');
            
            // 解锁车门
            simulateButtonAction(window.elements.unlockDoor);
        }, 2000);
    } else {
        // 验证失败
        showResultMessage('error', '身份验证失败，请重试。');
        
        // 更新安全检查状态
        updateSecurityCheck(livenessCheck, result.liveness);
        updateSecurityCheck(voiceprintMatch, false);
        
        // 重置UI
        setTimeout(resetVoiceprintUI, 3000);
    }
}

// 更新安全检查状态
function updateSecurityCheck(element, isPassed) {
    if (!element) return;
    
    if (isPassed) {
        element.classList.remove('failed');
        element.classList.add('passed');
        element.querySelector('.check-icon i').className = 'bi bi-check-circle-fill';
        element.querySelector('.check-status').textContent = '通过';
    } else {
        element.classList.remove('passed');
        element.classList.add('failed');
        element.querySelector('.check-icon i').className = 'bi bi-x-circle-fill';
        element.querySelector('.check-status').textContent = '未通过';
    }
}

// 显示声纹质量报告
function showVoiceprintReport(quality) {
    if (!quality) return;
    
    const { voiceprintReport } = window.elements;
    
    // 显示报告容器
    voiceprintReport.style.display = 'block';
    
    // 更新质量指标值
    const metrics = voiceprintReport.querySelectorAll('.metric-value');
    const numbers = voiceprintReport.querySelectorAll('.metric-number');
    
    // 唯一性
    metrics[0].style.width = `${quality.uniqueness}%`;
    numbers[0].textContent = `${quality.uniqueness}%`;
    
    // 稳定性
    metrics[1].style.width = `${quality.stability}%`;
    numbers[1].textContent = `${quality.stability}%`;
    
    // 清晰度
    metrics[2].style.width = `${quality.clarity}%`;
    numbers[2].textContent = `${quality.clarity}%`;
    
    // 更新建议
    const recommendations = voiceprintReport.querySelector('.report-recommendations');
    recommendations.innerHTML = '';
    
    if (quality.recommendations && quality.recommendations.length > 0) {
        quality.recommendations.forEach(recommendation => {
            const p = document.createElement('p');
            p.textContent = recommendation;
            recommendations.appendChild(p);
        });
    }
}

// 显示结果消息
function showResultMessage(type, message) {
    const { resultMessage, statusMessage } = window.elements;
    
    // 更新消息类型和内容
    resultMessage.className = `result-message ${type}`;
    resultMessage.textContent = message;
    resultMessage.style.display = 'block';
    
    // 清除状态消息
    statusMessage.textContent = '';
}

// 重置声纹验证UI状态
function resetVoiceprintUI() {
    const { 
        statusMessage, resultMessage, voiceprintReport,
        livenessCheck, voiceprintMatch
    } = window.elements;
    
    // 重置消息
    statusMessage.textContent = '请点击"开始录音"按钮进行声纹验证。';
    resultMessage.style.display = 'none';
    voiceprintReport.style.display = 'none';
    
    // 重置安全检查
    resetSecurityCheck(livenessCheck);
    resetSecurityCheck(voiceprintMatch);
}

// 重置安全检查状态
function resetSecurityCheck(element) {
    if (!element) return;
    
    element.classList.remove('passed', 'failed');
    element.querySelector('.check-icon i').className = 'bi bi-dash-circle-fill';
    element.querySelector('.check-status').textContent = '待验证';
}

// 初始化语音命令面板
function initCommandPanel() {
    const { 
        startCommandRecording, stopCommandRecording, 
        commandStatusMessage, commandResultMessage 
    } = window.elements;
    
    // 声纹分析器实例
    const voiceprintAnalyzer = new VoiceprintAnalyzer();
    
    // 录音状态
    let isRecording = false;
    let recordedAudio = null;
    
    // 开始录音按钮点击事件
    startCommandRecording.addEventListener('click', function() {
        // 重置UI状态
        resetCommandUI();
        
        // 开始录音
        voiceprintAnalyzer.startRecording()
            .then(() => {
                // 更新UI状态
                isRecording = true;
                startCommandRecording.disabled = true;
                stopCommandRecording.disabled = false;
                commandStatusMessage.textContent = '正在录音，请说出您的命令...';
                
                // 开始音频可视化
                startVisualization(window.elements.commandVisualizer);
            })
            .catch(error => {
                console.error('录音启动失败:', error);
                commandStatusMessage.textContent = '无法启动录音: ' + error.message;
            });
    });
    
    // 停止录音按钮点击事件
    stopCommandRecording.addEventListener('click', function() {
        if (!isRecording) return;
        
        // 停止录音
        voiceprintAnalyzer.stopRecording()
            .then(audio => {
                // 保存录制的音频
                recordedAudio = audio;
                
                // 更新UI状态
                isRecording = false;
                startCommandRecording.disabled = false;
                stopCommandRecording.disabled = true;
                commandStatusMessage.textContent = '正在处理您的命令，请稍候...';
                
                // 停止音频可视化
                stopVisualization(window.elements.commandVisualizer);
                
                // 处理语音命令
                processVoiceCommand(audio);
            })
            .catch(error => {
                console.error('停止录音失败:', error);
                commandStatusMessage.textContent = '停止录音失败: ' + error.message;
            });
    });
}

// 处理语音命令
function processVoiceCommand(audio) {
    const { commandStatusMessage, commandResultMessage } = window.elements;
    
    // 实例化声纹分析器
    const voiceprintAnalyzer = new VoiceprintAnalyzer();
    
    // 分析语音命令
    voiceprintAnalyzer.processCommand(audio)
        .then(result => {
            if (result.success) {
                // 命令识别成功
                commandStatusMessage.textContent = '';
                showCommandResult('success', `命令已识别: "${result.command}"，正在执行...`);
                
                // 根据命令更新UI
                executeCommand(result.command);
            } else {
                // 命令识别失败
                commandStatusMessage.textContent = '';
                showCommandResult('error', `命令无法识别: ${result.message || '请重试'}`);
            }
        })
        .catch(error => {
            console.error('处理语音命令失败:', error);
            commandStatusMessage.textContent = '';
            showCommandResult('error', '处理语音命令失败: ' + error.message);
        });
}

// 执行语音命令
function executeCommand(command) {
    if (!command) return;
    
    // 模拟命令执行延迟
    setTimeout(() => {
        // 根据命令执行相应操作
        if (command.includes('打开车门')) {
            // 切换到车门控制面板
            switchToTab('door-panel');
            // 解锁车门
            updateDoorStatus('unlocked');
        } else if (command.includes('锁定车门')) {
            // 切换到车门控制面板
            switchToTab('door-panel');
            // 锁定车门
            updateDoorStatus('locked');
        } else if (command.includes('打开后备箱')) {
            // 切换到车门控制面板
            switchToTab('door-panel');
            // 模拟后备箱操作
            simulateButtonAction(window.elements.trunkBtn);
        } else if (command.includes('打开车窗') || command.includes('关闭车窗')) {
            // 切换到车门控制面板
            switchToTab('door-panel');
            // 模拟车窗操作
            simulateButtonAction(window.elements.windowBtn);
        }
        
        // 更新命令结果消息
        showCommandResult('success', `命令 "${command}" 已执行成功!`);
    }, 1500);
}

// 切换到指定选项卡
function switchToTab(tabId) {
    // 寻找对应的选项卡
    window.tabs.forEach(tab => {
        if (tab.dataset.target === tabId) {
            tab.click();
        }
    });
}

// 模拟按钮点击效果
function simulateButtonAction(button) {
    if (!button) return;
    
    // 添加点击效果类
    button.classList.add('btn-active');
    
    // 移除效果
    setTimeout(() => {
        button.classList.remove('btn-active');
    }, 300);
}

// 显示命令结果消息
function showCommandResult(type, message) {
    const { commandResultMessage } = window.elements;
    
    // 更新消息类型和内容
    commandResultMessage.className = `result-message ${type}`;
    commandResultMessage.textContent = message;
    commandResultMessage.style.display = 'block';
    
    // 自动隐藏消息
    if (type === 'success') {
        setTimeout(() => {
            commandResultMessage.style.display = 'none';
        }, 5000);
    }
}

// 重置语音命令UI状态
function resetCommandUI() {
    const { commandStatusMessage, commandResultMessage } = window.elements;
    
    // 重置消息
    commandStatusMessage.textContent = '请点击"开始录音"按钮并说出您的命令。';
    commandResultMessage.style.display = 'none';
}

// 初始化车门控制面板
function initDoorPanel() {
    const { 
        vehicleSelect, unlockDoor, lockDoor, 
        trunkBtn, windowBtn 
    } = window.elements;
    
    // 车辆选择事件
    vehicleSelect.addEventListener('change', function() {
        // 更新车辆相关UI
        const selectedVehicle = this.value;
        console.log('选择的车辆:', selectedVehicle);
        
        // 此处可以根据选择的车辆更新车辆图标等信息
    });
    
    // 解锁车门按钮点击事件
    unlockDoor.addEventListener('click', function() {
        // 显示验证确认
        if (confirm('需要进行声纹验证才能解锁车门。是否继续?')) {
            // 切换到声纹验证面板
            switchToTab('voiceprint-panel');
            // 添加引导提示
            window.elements.statusMessage.textContent = '请完成声纹验证以解锁车门。';
        }
    });
    
    // 锁定车门按钮点击事件
    lockDoor.addEventListener('click', function() {
        // 更新车门状态
        updateDoorStatus('locked');
    });
    
    // 后备箱按钮点击事件
    trunkBtn.addEventListener('click', function() {
        alert('后备箱已打开!');
    });
    
    // 车窗按钮点击事件
    windowBtn.addEventListener('click', function() {
        alert('车窗已打开!');
    });
}

// 更新车门状态
function updateDoorStatus(status) {
    const { doorStatus, unlockDoor, lockDoor, autoLockInfo } = window.elements;
    
    if (status === 'unlocked') {
        // 解锁状态
        doorStatus.textContent = '已解锁';
        doorStatus.classList.add('unlocked');
        unlockDoor.style.display = 'none';
        lockDoor.style.display = 'block';
        autoLockInfo.style.display = 'block';
        
        // 设置自动锁定计时器
        startAutoLockCountdown(30);
    } else {
        // 锁定状态
        doorStatus.textContent = '已锁定';
        doorStatus.classList.remove('unlocked');
        unlockDoor.style.display = 'block';
        lockDoor.style.display = 'none';
        autoLockInfo.style.display = 'none';
        
        // 清除自动锁定计时器
        clearAutoLockCountdown();
    }
}

// 自动锁定倒计时
let autoLockTimer;
function startAutoLockCountdown(seconds) {
    // 清除现有计时器
    clearAutoLockCountdown();
    
    // 获取自动锁定信息元素
    const { autoLockInfo } = window.elements;
    
    // 初始化倒计时
    let countdown = seconds;
    updateCountdownText(countdown);
    
    // 设置新的计时器
    autoLockTimer = setInterval(() => {
        countdown--;
        updateCountdownText(countdown);
        
        // 倒计时结束
        if (countdown <= 0) {
            clearInterval(autoLockTimer);
            updateDoorStatus('locked');
        }
    }, 1000);
}

// 更新倒计时文本
function updateCountdownText(seconds) {
    const { autoLockInfo } = window.elements;
    autoLockInfo.textContent = `${seconds}秒后自动锁定`;
}

// 清除自动锁定计时器
function clearAutoLockCountdown() {
    if (autoLockTimer) {
        clearInterval(autoLockTimer);
        autoLockTimer = null;
    }
}

// 初始化侧边栏折叠功能
function initSidebar() {
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.querySelector('.sidebar');
    const mainContent = document.querySelector('.main-content');
    
    if (menuToggle) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            mainContent.classList.toggle('expanded');
        });
    }
}

// 初始化音频可视化
function initAudioVisualizer() {
    // 创建音频可视化器
    window.visualizers = {};
    
    // 初始化可视化器
    if (window.elements.visualizer) {
        window.visualizers.main = createVisualizer(window.elements.visualizer);
    }
    
    if (window.elements.commandVisualizer) {
        window.visualizers.command = createVisualizer(window.elements.commandVisualizer);
    }
}

// 创建可视化器
function createVisualizer(canvas) {
    if (!canvas) return null;
    
    const ctx = canvas.getContext('2d');
    
    // 设置画布大小
    function resizeCanvas() {
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
    }
    
    // 初始调整大小
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);
    
    // 返回可视化器对象
    return {
        canvas,
        ctx,
        isActive: false,
        animationId: null
    };
}

// 开始可视化
function startVisualization(canvas) {
    if (!canvas) return;
    
    // 获取可视化器
    let visualizer;
    if (canvas === window.elements.visualizer) {
        visualizer = window.visualizers.main;
    } else if (canvas === window.elements.commandVisualizer) {
        visualizer = window.visualizers.command;
    }
    
    if (!visualizer) return;
    
    // 标记为活动状态
    visualizer.isActive = true;
    
    // 绘制函数
    function draw() {
        if (!visualizer.isActive) return;
        
        const { ctx, canvas } = visualizer;
        const width = canvas.width;
        const height = canvas.height;
        
        // 清除画布
        ctx.clearRect(0, 0, width, height);
        
        // 绘制背景
        ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
        ctx.fillRect(0, 0, width, height);
        
        // 模拟音频波形
        ctx.beginPath();
        ctx.moveTo(0, height / 2);
        
        // 绘制波形
        const barCount = 100;
        const barWidth = width / barCount;
        
        for (let i = 0; i < barCount; i++) {
            // 生成随机波形高度
            const amplitude = Math.random() * 50 + 10;
            const y = (height / 2) + Math.sin(i * 0.1 + Date.now() * 0.005) * amplitude;
            
            ctx.lineTo(i * barWidth, y);
        }
        
        ctx.lineTo(width, height / 2);
        ctx.strokeStyle = '#1abc9c';
        ctx.lineWidth = 2;
        ctx.stroke();
        
        // 循环动画
        visualizer.animationId = requestAnimationFrame(draw);
    }
    
    // 开始动画
    draw();
}

// 停止可视化
function stopVisualization(canvas) {
    if (!canvas) return;
    
    // 获取可视化器
    let visualizer;
    if (canvas === window.elements.visualizer) {
        visualizer = window.visualizers.main;
    } else if (canvas === window.elements.commandVisualizer) {
        visualizer = window.visualizers.command;
    }
    
    if (!visualizer) return;
    
    // 标记为非活动状态
    visualizer.isActive = false;
    
    // 取消动画帧
    if (visualizer.animationId) {
        cancelAnimationFrame(visualizer.animationId);
        visualizer.animationId = null;
    }
    
    // 最终绘制静止波形
    const { ctx, canvas: cnv } = visualizer;
    ctx.clearRect(0, 0, cnv.width, cnv.height);
    
    // 绘制背景
    ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
    ctx.fillRect(0, 0, cnv.width, cnv.height);
    
    // 绘制水平线
    ctx.beginPath();
    ctx.moveTo(0, cnv.height / 2);
    ctx.lineTo(cnv.width, cnv.height / 2);
    ctx.strokeStyle = '#95a5a6';
    ctx.lineWidth = 2;
    ctx.stroke();
} 