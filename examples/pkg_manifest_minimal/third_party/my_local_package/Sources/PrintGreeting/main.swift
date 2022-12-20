import GreetingsFramework

let jim = WithName("Jim")
let namedGreeting = NamedGreeting(EveningGreeting(), jim)
print(namedGreeting.value)
