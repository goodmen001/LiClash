# ICMP 转发功能文档

## 功能概述

在基本设置 -> 网络 -> 选项部分，栈模式上方新增"ICMP转发"选项，用于控制内核是否接收 ICMP 请求。

## 实现细节

### 1. 配置字段

**内核字段**：`disable-icmp-forwarding` (boolean)
- `true`: 禁用 ICMP 转发（默认值）
- `false`: 启用 ICMP 转发

**UI 显示逻辑**：取反显示
- 开关关闭 → `disable-icmp-forwarding = true` → 禁用 ICMP
- 开关开启 → `disable-icmp-forwarding = false` → 启用 ICMP

### 2. 文件修改

#### lib/views/config/network.dart
新增 `IcmpForwardingItem` 组件：
```dart
class IcmpForwardingItem extends ConsumerWidget {
  @override
  Widget build(BuildContext context, ref) {
    // 取反显示：disableIcmpForwarding=true 时，UI 显示为关闭
    final icmpForwarding = ref.watch(
      patchClashConfigProvider.select(
        (state) => !state.tun.disableIcmpForwarding,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.icmpForwarding),
      subtitle: Text(appLocalizations.icmpForwardingDesc),
      delegate: SwitchDelegate(
        value: icmpForwarding,
        onChanged: (value) async {
          // 取反后传递给内核
          ref.read(patchClashConfigProvider.notifier).updateState(
                (state) => state.copyWith.tun(
                  disableIcmpForwarding: !value,
                ),
              );
          // 重新加载配置使设置立即生效
          await globalState.appController.updateClashConfig();
        },
      ),
    );
  }
}
```

添加到网络设置列表（栈模式上方）：
```dart
...generateSection(
  title: appLocalizations.options,
  items: [
    if (system.isDesktop) const TUNItem(),
    if (system.isMacOS) const AutoSetSystemDnsItem(),
    const IcmpForwardingItem(),  // 新增
    const TunStackItem(),
    ...
  ],
),
```

#### 国际化文件

**arb/intl_zh_CN.arb**:
```json
"icmpForwarding": "ICMP转发",
"icmpForwardingDesc": "开启后将支持ICMPing",
```

**arb/intl_en.arb**:
```json
"icmpForwarding": "ICMP Forwarding",
"icmpForwardingDesc": "Enable ICMPing Support",
```

**lib/l10n/l10n.dart**:
```dart
String get icmpForwarding {
  return Intl.message('ICMP Forwarding', name: 'icmpForwarding', desc: '', args: []);
}

String get icmpForwardingDesc {
  return Intl.message('Enable ICMPing Support', name: 'icmpForwardingDesc', desc: '', args: []);
}
```

**lib/l10n/intl/messages_zh_CN.dart** 和 **messages_en.dart**:
```dart
"icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP转发"),
"icmpForwardingDesc": MessageLookupByLibrary.simpleMessage("开启后将支持ICMPing"),
```

### 3. 配置传递流程

```
用户操作 UI
    ↓
IcmpForwardingItem.onChanged(value)
    ↓
patchClashConfigProvider.updateState()
    ↓
state.copyWith.tun(disableIcmpForwarding: !value)
    ↓
configState provider 监听变化
    ↓
clashCore.updateConfig(UpdateParams)
    ↓
UpdateParams 包含 Tun 对象
    ↓
Tun 对象序列化为 JSON
    ↓
{
  "tun": {
    "disable-icmp-forwarding": true/false,
    ...
  }
}
    ↓
传递给 Mihomo 内核
    ↓
内核应用配置
```

### 4. 数据模型

**lib/models/clash_config.dart** (已存在):
```dart
@freezed
class Tun with _$Tun {
  const factory Tun({
    @Default(false) bool enable,
    @Default(appName) String device,
    @JsonKey(name: 'auto-route') @Default(false) bool autoRoute,
    @Default(TunStack.system) TunStack stack,
    @JsonKey(name: 'dns-hijack') @Default(['any:53']) List<String> dnsHijack,
    @JsonKey(name: 'route-address') @Default([]) List<String> routeAddress,
    @JsonKey(name: 'disable-icmp-forwarding') @Default(true) bool disableIcmpForwarding,
  }) = _Tun;
}
```

**lib/models/core.dart** (已存在):
```dart
class UpdateParams with _$UpdateParams {
  const factory UpdateParams({
    required Tun tun,  // 包含 disableIcmpForwarding
    ...
  }) = _UpdateParams;
}
```

### 5. 验证配置生效

配置通过以下路径确保生效：

1. **UI 层**：`IcmpForwardingItem` 读取和更新 `patchClashConfigProvider`
2. **状态层**：`patchClashConfigProvider` 是 `Config` 的一部分
3. **传递层**：`clashCore.updateConfig()` 接收 `UpdateParams`
4. **序列化层**：`Tun` 对象通过 `@JsonKey(name: 'disable-icmp-forwarding')` 正确序列化
5. **内核层**：Mihomo 内核接收 JSON 配置并应用

## UI 展示

```
┌─────────────────────────────────────┐
│ 选项                                 │
├─────────────────────────────────────┤
│ TUN                          [开关]  │
│ 自动设置系统DNS              [开关]  │
│                                      │
│ ICMP转发                     [开关]  │  ← 新增
│ 开启后将支持ICMPing                │
│                                      │
│ 栈模式                               │
│ system                        >      │
└─────────────────────────────────────┘
```

## 测试要点

1. **UI 显示**
   - [ ] ICMP转发选项显示在栈模式上方
   - [ ] 标题显示"ICMP转发"（中文）/"ICMP Forwarding"（英文）
   - [ ] 描述显示"开启后将支持ICMPing"（中文）/"Enable ICMPing Support"（英文）

2. **功能测试**
   - [ ] 默认状态：开关关闭（对应 `disable-icmp-forwarding=true`）
   - [ ] 开启开关后，配置中 `disable-icmp-forwarding` 变为 `false`
   - [ ] 关闭开关后，配置中 `disable-icmp-forwarding` 变为 `true`
   - [ ] 配置变化后自动应用到内核

3. **持久化测试**
   - [ ] 修改设置后重启应用，设置保持
   - [ ] 导出配置文件，包含正确的 `disable-icmp-forwarding` 值

4. **功能验证**
   - [ ] 开启 ICMP 转发后，可以 ping 通目标地址
   - [ ] 关闭 ICMP 转发后，ping 请求被阻止

## 注意事项

1. **取反逻辑**：UI 显示的是"启用 ICMP 转发"，但内核字段是"禁用 ICMP 转发"，因此需要取反
2. **默认值**：内核默认 `disable-icmp-forwarding=true`，即默认禁用 ICMP
3. **平台支持**：所有平台（Android、Windows、macOS、Linux）都支持此功能
4. **依赖关系**：此功能独立于其他网络设置，不需要特殊依赖

## 状态
✅ 实现完成 - 已修复立即生效问题

## 修复记录

### 2025-01-01: 修复 ICMP 转发开关不立即生效的问题
- **问题**：用户切换 ICMP 转发开关后，设置不会立即生效，需要重启或重新加载配置
- **原因**：`onChanged` 回调只更新了配置状态，但没有触发配置重新加载
- **解决方案**：在 `onChanged` 回调中添加 `await globalState.appController.updateClashConfig()` 调用
- **影响**：现在切换开关后，配置会立即应用到内核，无需手动重启
