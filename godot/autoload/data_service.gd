class_name GameDataService
extends Node

## 全局数据服务：跨场景共享 RuntimeDataRegistry 单一实例。
## 生命周期：应用启动 → 退出。
##
## 边界：只放数据访问，不放状态机或玩法规则。
## NoncombatDomain 等玩法对象必须保持可实例化，否则测试无法隔离。
##
## 回退：`--script` 测试模式与独立场景可能未加载本 autoload，
## 调用方通过 registry_or_new() 取用——自建是正常路径，不是异常分支。

var registry: RuntimeDataRegistry


func _ready() -> void:
	registry = RuntimeDataRegistry.new()


## 有共享实例则复用，否则新建。两条路径都合法。
func registry_or_new() -> RuntimeDataRegistry:
	if registry != null:
		return registry
	registry = RuntimeDataRegistry.new()
	return registry
