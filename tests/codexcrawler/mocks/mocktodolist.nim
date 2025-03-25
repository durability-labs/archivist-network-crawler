import pkg/chronos
import pkg/questionable/results

import ../../../codexcrawler/components/todolist
import ../../../codexcrawler/types

type MockTodoList* = ref object of TodoList
  popReturn*: ?!Nid

method pop*(t: MockTodoList): Future[?!Nid] {.async: (raises: []).} =
  return t.popReturn

proc createMockTodoList*(): MockTodoList =
  MockTodoList()
