#!/usr/bin/env python3
"""
批量生成 NORMAL 卡牌 choice.desc 叙事描述字段。

读取 index.html 中的 DATA_MODULES，为所有无 desc 的 NORMAL 卡自动
生成选择后果叙事描述，基于卡牌 title/description/effects/choice.text。

用法：
    python tools/generate_choice_descs.py [--dry-run] [--realm qi]
"""

import json, re, sys, os, random

# ── 效果→叙事模板 ──
EFFECT_TEMPLATES = {
    # 正收益模板
    ('cultivation', '+'): [
        '灵气入体，修为凝实了几分。',
        '你对大道的感悟又深了一层。',
        '此番历练，化为修行资粮。',
    ],
    ('health', '+'): [
        '伤势好转，经脉畅通了几分。',
        '调息之后，内伤已无大碍。',
        '丹药之力在体内化开，伤势恢复。',
    ],
    ('daoHeart', '+'): [
        '你的道心愈发坚定。',
        '本心澄澈，不染尘埃。',
        '道心微芒，照亮前路。',
    ],
    ('spiritStone', '+'): [
        '几枚灵石落入口袋。',
        '这笔灵石够花一阵子了。',
        '财路来了——虽然不多。',
    ],
    ('karmaGood', '+'): [
        '善念一动，功德加身。',
        '你在黑暗中点了一盏灯。',
    ],
    ('fortune', '+'): [
        '冥冥中，气运似有转机。',
        '命运的丝线微微一颤。',
        '今日运势不错。',
    ],
    ('knowledge', '+'): [
        '这番见闻让眼界开阔了几分。',
        '其中大有学问——日后或许用得上。',
        '修行路上，见识也是资粮。',
    ],
    ('exp', '+'): [
        '瓶颈松动了一丝。',
        '隐隐触摸到了下一个境界的门槛。',
    ],
    # 负收益模板
    ('cultivation', '-'): [
        '心神不稳，修为散逸了几分。',
        '这一遭白费了不少苦功。',
    ],
    ('health', '-'): [
        '伤势加重，经脉隐隐作痛。',
        '体内气血翻涌——这一下伤得不轻。',
    ],
    ('daoHeart', '-'): [
        '道心动摇，前路迷雾重重。',
        '你的信念受到了考验。',
    ],
    ('karmaBad', '+'): [
        '手上沾了不该沾的血。',
        '恶业已种——天网恢恢。',
        '杀意入心。道心蒙尘。',
    ],
    ('fortune', '-'): [
        '运气似乎站在了对立面。',
        '晦气缠身，诸事不顺。',
    ],
    ('lifespan', '-'): [
        '寿元又短了一分。',
        '烛火摇曳——修仙之路，是与时间的赛跑。',
    ],
    # 资源获取模板
    ('pill', '+'): [
        '丹药入手——药香扑鼻。',
        '这颗丹或许能在关键时刻救命。',
    ],
    ('treasure', '+'): [
        '一件法宝被你收入囊中。',
        '这等机缘，可遇不可求。',
    ],
    ('companion', '+'): [
        '某个人的态度悄然改变。',
        '缘分的丝线，在这一刻交织。',
    ],
}

# ── 选择类型→叙事模板 ──
CHOICE_TYPE_TEMPLATES = {
    '冒险': ['赌一把运气。', '不入虎穴，焉得虎子。', '明知山有虎——但你还是要走这一遭。'],
    '谨慎': ['安全第一——这趟浑水不值得蹚。', '你按住了冲动。来日方长。', '谨慎行事，总不会错。'],
    '帮助': ['伸手扶一把——结个善缘。', '帮人就是帮自己——修真界有时也需要人情。', '你选择了伸出援手。'],
    '拒绝': ['各人自扫门前雪——你选择了袖手旁观。', '事不关己。你转身离去。', '这忙——帮不得。'],
    '战斗': ['剑已出鞘。', '灵力在经脉中奔涌——这一战在所难免。', '先下手为强。'],
    '和平': ['拳头解决不了所有问题。', '你收起了灵力——以理服人。', '动手之前，先问个明白。'],
    '探索': ['好奇心驱使你走了进去。', '前方未知——但你选择一探究竟。', '机缘从来只眷顾敢于前进的人。'],
    '学习': ['知识就是力量——尤其是在修真界。', '你细细品味这卷记载。', '多一分见识，少一分危险。'],
    '交易': ['一手交钱，一手交货。', '这买卖不亏。', '灵石换来的东西，值不值只有自己知道。'],
    '修炼': ['静下心来，运转周天。', '修行如逆水行舟——不进则退。', '这一夜，灵气在经脉中缓缓流动。'],
    '社交': ['你开口攀谈——先探探对方的底。', '几句话——或许能打开一扇门。', '修真界的人脉，有时比灵石更管用。'],
    '沉默': ['多听，少说。', '沉默也是一种态度。', '你选择了观察——有时候不说话就是最好的回答。'],
}

# ── 根据 choice.text 推断选择类型 ──
def classify_choice(choice_text):
    text = choice_text.strip()
    patterns = {
        '冒险': ['冒险', '前往', '进去', '探', '闯', '深入', '前去'],
        '谨慎': ['避开', '绕道', '离开', '退', '撤', '多加小心', '远远'],
        '帮助': ['帮助', '帮忙', '援手', '救', '施以', '帮他', '教他'],
        '拒绝': ['拒绝', '不管', '不理', '不与', '不必', '袖手', '不帮'],
        '战斗': ['攻击', '战斗', '拔剑', '动手', '迎战', '杀', '打'],
        '和平': ['商量', '谈判', '劝说', '和解', '调和', '以理'],
        '探索': ['探索', '搜寻', '查看', '调查', '观察', '寻找', '挖'],
        '学习': ['学习', '研读', '参悟', '修炼', '记下', '请教', '求教'],
        '交易': ['交易', '购买', '卖出', '交易', '换取', '买', '卖', '付'],
        '修炼': ['修炼', '运功', '打坐', '闭关', '调息', '稳固', '巩固'],
        '社交': ['交谈', '询问', '攀谈', '聊聊', '打听', '套'],
        '沉默': ['沉默', '不说', '无视', '不理', '保持', '不语'],
    }
    for category, keywords in patterns.items():
        for kw in keywords:
            if kw in text:
                return category
    return None

def generate_desc(card, choice_text, effects):
    """为一条choice生成叙事描述"""
    lines = []

    # 1. 效果叙事
    for key, value in sorted(effects.items()):
        # 处理可能为字符串的效果值
        try:
            numeric_value = int(value) if isinstance(value, str) else value
        except (ValueError, TypeError):
            numeric_value = 0
        if numeric_value == 0:
            continue
        sign = '+' if numeric_value > 0 else '-'
        abs_val = abs(int(numeric_value))
        templates_key = (key, sign)
        templates = EFFECT_TEMPLATES.get(templates_key)
        if templates:
            lines.append(random.choice(templates))
        # 数值型效果追加数值
        if key in ('cultivation', 'health', 'daoHeart', 'spiritStone',
                    'karmaGood', 'karmaBad', 'fortune', 'knowledge', 'exp', 'lifespan'):
            if lines and numeric_value != 0:
                lines[-1] += f' {sign}{abs_val}'

    # 2. 选择类型叙事（如果没有效果描述则用类型叙事兜底）
    if not lines:
        cat = classify_choice(choice_text)
        if cat and cat in CHOICE_TYPE_TEMPLATES:
            lines.append(random.choice(CHOICE_TYPE_TEMPLATES[cat]))

    # 3. 如果还是没有——兜底
    if not lines:
        lines.append('此路通往未知。')

    return '。'.join(lines) + '。'


def process_realm(dry_run, realm_name, cards_data):
    """处理单个境界的卡牌数据"""
    cards = cards_data.get('cards', [])
    normal_cards = [c for c in cards if c.get('type') == 'NORMAL']
    modified = 0

    for card in normal_cards:
        choices = card.get('choices', {})
        for direction in ['left', 'right', 'up', 'down']:
            choice = choices.get(direction)
            if not choice:
                continue
            if 'desc' in choice and choice['desc']:
                continue  # 已有描述
            effects = choice.get('effects', {})
            choice_text = choice.get('text', '')
            desc = generate_desc(card, choice_text, effects)
            if dry_run:
                print(f'  [{realm_name}] {card["id"]} [{direction}]: "{choice_text}" → "{desc}"')
            else:
                choice['desc'] = desc
            modified += 1

    return modified


def main():
    dry_run = '--dry-run' in sys.argv
    realm_filter = None
    for i, arg in enumerate(sys.argv):
        if arg == '--realm' and i + 1 < len(sys.argv):
            realm_filter = sys.argv[i + 1].lower()

    # 读取 index.html
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    index_path = os.path.join(project_dir, 'index.html')
    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取 DATA_MODULES
    match = re.search(r'const DATA_MODULES = ({.*?});', content, re.DOTALL)
    if not match:
        print('ERROR: Could not find DATA_MODULES in index.html')
        sys.exit(1)

    jstr = match.group(1)
    data = json.loads(jstr)

    realms = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation']
    if realm_filter:
        realms = [r for r in realms if r == realm_filter]

    total_modified = 0
    for realm in realms:
        key = f'cards:{realm}'
        if key not in data:
            print(f'  Skipping {realm} (not in DATA_MODULES)')
            continue
        modified = process_realm(dry_run, realm, data[key])
        total_modified += modified
        if modified > 0:
            print(f'  {realm}: {modified} choices updated')

    if dry_run:
        print(f'\n[Dry-run] 共 {total_modified} 条选择将生成描述')
        print('运行 "python tools/generate_choice_descs.py" 写入')  
    else:
        # 回写 index.html
        new_jstr = json.dumps(data, ensure_ascii=False, indent=2)
        new_content = content.replace(jstr, new_jstr)
        with open(index_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'\n完成！共为 {total_modified} 条选择生成了叙事描述。')
        print(f'已写入: {index_path}')

if __name__ == '__main__':
    main()
