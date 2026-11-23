# Nola Android R8 混淆规则。
#
# Flutter 及本项目的插件（webview_flutter / file_picker / share_plus /
# shared_preferences）均通过 AAR 自带的 consumer proguard 规则保持必要类，
# 此文件仅存放项目自定义规则。如运行时因混淆出现缺类崩溃，在此追加 keep 规则。
