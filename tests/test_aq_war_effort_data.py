import re
import unittest
from pathlib import Path


EXPECTED_QUEST_IDS = {
    8492, 8493, 8494, 8495, 8499, 8500, 8503, 8504, 8505, 8506,
    8509, 8510, 8511, 8512, 8513, 8514, 8515, 8516, 8517, 8518,
    8520, 8521, 8522, 8523, 8524, 8525, 8526, 8527, 8528, 8529,
    8532, 8533, 8542, 8543, 8545, 8546, 8549, 8550, 8580, 8581,
    8582, 8583, 8588, 8589, 8590, 8591, 8600, 8601, 8604, 8605,
    8607, 8608, 8609, 8610, 8611, 8612, 8613, 8614, 8615, 8616,
    8743, 8792, 8793, 8794, 8795, 8796, 8797, 8811, 8812, 8813,
    8814, 8815, 8816, 8817, 8818, 8819, 8820, 8821, 8822, 8823,
    8824, 8825, 8826, 8830, 8831, 8832, 8833, 8834, 8835, 8836,
    8837, 8838, 8839, 8840, 8841, 8842, 8843, 8844, 8845, 8846,
    8847, 8848, 8849, 8850, 8851, 8852, 8853, 8854, 8855, 10500,
    10501,
}


class AQWarEffortDataTests(unittest.TestCase):
    def test_matches_questie_war_effort_set(self):
        path = Path(__file__).parents[1] / "Database" / "Classic" / "AQWarEffortQuests.lua"
        contents = path.read_text(encoding="utf-8")
        actual_ids = {int(value) for value in re.findall(r"\[(\d+)\]\s*=\s*true", contents)}

        self.assertEqual(EXPECTED_QUEST_IDS, actual_ids)


if __name__ == "__main__":
    unittest.main()
