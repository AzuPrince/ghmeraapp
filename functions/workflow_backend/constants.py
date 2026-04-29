from __future__ import annotations

RECIPROCITY_FLOOR = -5
REQUESTER_SUGGESTION_LIMIT = 3
HELPER_BROADCAST_LIMIT: int | None = None
MINUTES_PER_DAY = 24 * 60
BLOCKED_RESTRICTION_STATUSES = {'suspended', 'banned'}
HIGH_RISK_CATEGORIES = {'childcare', 'elderlySupport', 'emergencySupport'}
CATEGORY_LABELS = {
    'errands': 'Errands',
    'transportation': 'Transportation',
    'studyHelp': 'Study help',
    'technicalSupport': 'Technical support',
    'emotionalSupport': 'Emotional support',
    'prayerSupport': 'Prayer / spiritual support',
    'childcare': 'Childcare',
    'elderlySupport': 'Elderly support',
    'movingHelp': 'Moving help',
    'informationAdvice': 'Information / advice',
    'foodSupport': 'Food support',
    'emergencySupport': 'Emergency non-medical support',
}
RELATED_CATEGORIES = {
    'errands': {'transportation', 'foodSupport', 'movingHelp'},
    'transportation': {'errands', 'elderlySupport', 'foodSupport'},
    'studyHelp': {'technicalSupport', 'informationAdvice'},
    'technicalSupport': {'studyHelp', 'informationAdvice'},
    'emotionalSupport': {'prayerSupport', 'informationAdvice'},
    'prayerSupport': {'emotionalSupport'},
    'childcare': {'emotionalSupport', 'foodSupport'},
    'elderlySupport': {'transportation', 'errands', 'emotionalSupport'},
    'movingHelp': {'errands', 'transportation'},
    'informationAdvice': {
        'studyHelp',
        'technicalSupport',
        'emotionalSupport',
    },
    'foodSupport': {'errands', 'transportation'},
    'emergencySupport': {'transportation', 'elderlySupport', 'errands'},
}