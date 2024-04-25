import Collections

var deque: Deque<String> = ["Ted", "Rebecca"]
deque.prepend("Keeley")
deque.append("Nathan")
print(deque) // ["Keeley", "Ted", "Rebecca", "Nathan"]
