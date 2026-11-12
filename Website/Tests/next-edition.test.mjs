import test from "node:test";
import assert from "node:assert/strict";
import { nextEdition } from "../Assets/next-edition.mjs";

const editions = [
  { id: "later", startDate: "2027-06-10", endDate: "2027-06-12" },
  { id: "past", startDate: "2026-02-01", endDate: "2026-02-03" },
  { id: "arctic-2027", startDate: "2027-02-02", endDate: "2027-02-04" }
];

test("features the nearest edition across conferences, regardless of catalogue order", () => {
  assert.equal(nextEdition(editions, "2026-11-12").id, "arctic-2027");
  assert.equal(editions[0].id, "later");
});

test("keeps a current edition through its last day, then rolls forward", () => {
  assert.equal(nextEdition(editions, "2027-02-02").id, "arctic-2027");
  assert.equal(nextEdition(editions, "2027-02-04").id, "arctic-2027");
  assert.equal(nextEdition(editions, "2027-02-05").id, "later");
});

test("does not feature a past edition when none remain", () => {
  assert.equal(nextEdition(editions, "2027-06-13"), undefined);
  assert.equal(nextEdition([], "2026-11-12"), undefined);
});

test("same-day editions have a stable choice", () => {
  const sameDay = [
    { id: "z", startDate: "2027-02-02", endDate: "2027-02-04" },
    { id: "a", startDate: "2027-02-02", endDate: "2027-02-03" }
  ];
  assert.equal(nextEdition(sameDay, "2027-02-01").id, "a");
});

test("same-day choice matches Swift for mixed case and normalized Unicode IDs", () => {
  for (const [expected, other] of [["B", "a"], ["z", "é"], ["z", "e\u0301"], ["\uE000", "😀"]]) {
    for (const ids of [[other, expected], [expected, other]]) {
      const input = ids.map(id => ({ id, startDate: "2027-02-02", endDate: "2027-02-04" }));
      assert.equal(nextEdition(input, "2027-02-01").id, expected);
    }
  }
});
