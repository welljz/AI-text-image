import json
import os
from datetime import datetime

index_path = '/var/www/aipic/history/index.json'
history_dir = '/var/www/aipic/history/'

with open(index_path, 'r') as f:
    index = json.load(f)

changed = 0
for rec in index['records']:
    record_path = os.path.join(history_dir, f"{rec['id']}.json")
    if not os.path.exists(record_path):
        continue
    with open(record_path, 'r') as f:
        detail = json.load(f)

    old_updated = detail.get('updated_at', '')
    old_dt = datetime.fromisoformat(old_updated)

    # 判断是否被今天的扫描误刷了
    if old_dt.date() != datetime.now().date():
        continue  # 今天的之前的日期，应该是正确的

    # 尝试从任务目录获取真实完成时间
    task_id = detail.get('images', {}).get('task_id')
    new_updated = None
    if task_id:
        task_dir = os.path.join(history_dir, task_id)
        if os.path.isdir(task_dir):
            mtime = os.path.getmtime(task_dir)
            new_updated = datetime.fromtimestamp(mtime).isoformat()

    # 回退：用 created_at
    if not new_updated:
        new_updated = detail.get('created_at', old_updated)

    detail['updated_at'] = new_updated
    with open(record_path, 'w') as f:
        json.dump(detail, f, ensure_ascii=False, indent=2)
    rec['updated_at'] = new_updated
    print(f"  {rec['title'][:30]:30s}  {old_updated[:19]} -> {new_updated[:19]}")
    changed += 1

with open(index_path, 'w') as f:
    json.dump(index, f, ensure_ascii=False, indent=2)

print(f"\n修了 {changed} 条记录")
