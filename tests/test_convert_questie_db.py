import unittest

from tools.convert_questie_db import fmt_quest


def make_quest(required_skill=None):
    quest = [None] * 22
    quest[0] = "Test Quest"
    quest[1] = [[123]]
    quest[2] = [[456]]
    quest[3] = 10
    quest[4] = 12
    quest[5] = 0
    quest[6] = 0
    quest[9] = []
    quest[17] = required_skill
    return quest


class FormatQuestTests(unittest.TestCase):
    def test_emits_required_profession_and_rank(self):
        formatted = fmt_quest(1578, make_quest([164, 30]))

        self.assertIn("sk={164,30}", formatted)

    def test_emits_zero_rank_for_profession_only_requirement(self):
        formatted = fmt_quest(8869, make_quest([164, 0]))

        self.assertIn("sk={164,0}", formatted)

    def test_omits_missing_required_skill(self):
        formatted = fmt_quest(1, make_quest())

        self.assertNotIn("sk=", formatted)

    def test_omits_malformed_required_skill(self):
        formatted = fmt_quest(1, make_quest([164]))

        self.assertNotIn("sk=", formatted)


if __name__ == "__main__":
    unittest.main()
