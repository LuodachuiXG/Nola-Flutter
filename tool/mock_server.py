"""Nola 后端 Mock 服务器（仅供本地可视化验证 Flutter 界面使用）。

用法：python3 tool/mock_server.py [port]
所有 /admin 接口返回 code=200，列表接口返回空分页数据，
使 App 可以在无真实凭据的情况下渲染界面。
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def ok(data=None):
    return {"code": 200, "errMsg": None, "data": data}


def empty_pager():
    return {"page": 1, "size": 10, "data": [], "totalData": 0, "totalPages": 1}


NOW = int(time.time() * 1000)

# 内存菜单项数据（供拖动排序可视化验证）
MENU_ITEMS = [
    {"menuItemId": 1, "displayName": "首页", "href": "/", "target": "SELF",
     "parentMenuId": 1, "parentMenuItemId": None, "index": 0,
     "createTime": NOW, "lastModifyTime": NOW, "children": []},
    {"menuItemId": 2, "displayName": "归档", "href": "/archives", "target": "SELF",
     "parentMenuId": 1, "parentMenuItemId": None, "index": 1,
     "createTime": NOW, "lastModifyTime": NOW, "children": []},
    {"menuItemId": 3, "displayName": "友情链接", "href": "/links", "target": "SELF",
     "parentMenuId": 1, "parentMenuItemId": None, "index": 2,
     "createTime": NOW, "lastModifyTime": NOW,
     "children": [
         {"menuItemId": 4, "displayName": "友链申请", "href": "/links/apply",
          "target": "SELF", "parentMenuId": 1, "parentMenuItemId": 3,
          "index": 0, "createTime": NOW, "lastModifyTime": NOW},
     ]},
    {"menuItemId": 5, "displayName": "关于我", "href": "/about", "target": "SELF",
     "parentMenuId": 1, "parentMenuItemId": None, "index": 3,
     "createTime": NOW, "lastModifyTime": NOW, "children": []},
]


class Handler(BaseHTTPRequestHandler):
    def _send(self, payload, content_type="application/json", status=200):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header(
            "Access-Control-Allow-Headers", "Authorization, Content-Type"
        )
        self.send_header(
            "Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"
        )
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send(ok(True))

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/admin/overview/online":
            # SSE：发送一条在线人数后保持连接
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            event = json.dumps({"count": 3, "timestamp": NOW})
            self.wfile.write(f"data: {event}\n\n".encode("utf-8"))
            return
        if path == "/api/config/blog" or path == "/admin/config/blog":
            self._send(ok({
                "title": "Nola 视觉验证站", "subtitle": "Mock Backend",
                "blogger": "视觉验证", "logo": None, "favicon": None,
                "createDate": 1700000000000,
            }))
            return
        if path == "/admin/overview":
            self._send(ok({
                "postVisitCount": 12345,
                "count": {"post": 12, "tag": 5, "category": 3,
                          "comment": 28, "diary": 6, "file": 42,
                          "link": 8, "menu": 2},
                "tags": [{"tagId": 1, "displayName": "Flutter", "slug": "flutter",
                          "color": "#306FFF", "postCount": 6},
                         {"tagId": 2, "displayName": "Kotlin", "slug": "kotlin",
                          "color": "#8B5CF6", "postCount": 4}],
                "categories": [{"categoryId": 1, "displayName": "技术",
                                "slug": "tech", "cover": None,
                                "unifiedCover": False, "postCount": 8}],
                "mostViewedPost": {"postId": 1, "title": "欢迎使用 Nola",
                                   "excerpt": "", "slug": "first", "cover": None,
                                   "allowComment": True, "pinned": False,
                                   "encrypted": False, "visit": 999,
                                   "category": None, "tags": [],
                                   "createTime": NOW, "lastModifyTime": None},
                "lastOperation": "修改文章 [欢迎使用 Nola]",
                "lastLoginDate": NOW,
                "createDate": 1700000000000,
            }))
            return
        if path == "/admin/config/icp":
            self._send(ok({"icp": "京ICP备00000000号", "police": None}))
            return
        if path == "/admin/menu":
            self._send(ok(empty_pager() | {"data": [
                {"menuId": 1, "isMain": True, "displayName": "主菜单",
                 "createTime": NOW, "lastModifyTime": NOW},
            ], "totalData": 1, "totalPages": 1}))
            return
        if path.startswith("/admin/menu/item/"):
            # 按 index 排序返回树形菜单项
            top = sorted((i for i in MENU_ITEMS
                          if i["parentMenuItemId"] is None),
                         key=lambda i: i["index"])
            result = []
            for item in top:
                item = dict(item)
                item["children"] = sorted(
                    (i for i in MENU_ITEMS
                     if i["parentMenuItemId"] == item["menuItemId"]),
                    key=lambda i: i["index"])
                result.append(item)
            self._send(ok(result))
            return
        if path.startswith("/admin/"):
            self._send(ok(empty_pager()))
            return
        self._send(ok(None))

    def do_POST(self):
        self._send(ok(True))

    def do_PUT(self):
        path = self.path.split("?")[0]
        if path == "/admin/menu/item":
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length) or "{}")
            for item in MENU_ITEMS:
                if item["menuItemId"] == payload.get("menuItemId"):
                    item["index"] = payload.get("index", item["index"])
                    item["lastModifyTime"] = int(time.time() * 1000)
                    break
            self._send(ok(True))
            return
        self._send(ok(True))

    def do_DELETE(self):
        path = self.path.split("?")[0]
        if path == "/admin/menu/item":
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length) or "[]")
            ids = set(payload) if isinstance(payload, list) else set()
            MENU_ITEMS[:] = [i for i in MENU_ITEMS if i["menuItemId"] not in ids]
            self._send(ok(True))
            return
        self._send(ok(True))

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8932
    print(f"Mock server listening on http://127.0.0.1:{port}")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
