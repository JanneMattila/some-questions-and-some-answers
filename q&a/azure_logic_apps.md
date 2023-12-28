# Azure Logic Apps

## Grouping data

Here is example Logic App showing data grouping.

Incoming HTTP request:

```json
[
  {
    "warehouseId": "wh1",
    "itemId": "111",
    "name": "Name 1",
    "qty": 11
  },
  {
    "warehouseId": "wh1",
    "itemId": "222",
    "name": "Name 2",
    "qty": 22
  },
  {
    "warehouseId": "wh1",
    "itemId": "333",
    "name": "Name 3",
    "qty": 33
  },
  {
    "warehouseId": "wh2",
    "itemId": "222",
    "name": "Name 2",
    "qty": 222
  },
  {
    "warehouseId": "wh2",
    "itemId": "444",
    "name": "Name 4",
    "qty": 44
  }
]
```

You want to group data based on `warehouseId` and then send grouped data to next system.

First part of the Logic Apps is this:

![image](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/dabee331-00e3-4071-bd7c-50a55db09fd9)

It initializes `groupList` which is `array` and then
it fills it with all  `warehouseId` values from the incoming data.

![image](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/abdb1704-558a-469e-b6e5-860740dd50c4)

Second part of the Logic Apps is this:

![image](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/2ad09629-86c9-408b-b446-010a7acfd709)

It first creates distinct list of `warehouseId` values and then
sets that to the `distinctGroups` variable using this function:
```sql
union(variables('groupList'),variables('groupList'))
```

Next we look each value in `distinctGroups` using For each:

![image](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/094853c4-ab35-4d1d-b7aa-86133e22a5be)

Then we filter the original data based on the current `warehouseId` value:

![image](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/58ea0ef9-b445-428b-9867-ecb13aafcd79)

Now we can format our data to e.g., CSV:

![image](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/36dfaeaa-547b-43cd-a545-3235cd4630c3)

If we now post this data to e.g., HTTP endpoint, we get following data:

First call:

```csv
ID,Name,Quantity
111,Name 1,11
222,Name 2,22
333,Name 3,33
```

Second call:

```csv
ID,Name,Quantity
222,Name 2,222
444,Name 4,44
```
