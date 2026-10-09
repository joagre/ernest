# Svar: hur ett `Reply` typas, och vad som går att bevisa om det

Två frågor: var svarstypen i ett request-reply står, när den inte syns i den anropandes brevlådetyp, och om det verkligen går att kontrollera att `answer` anropas minst en och högst en gång.

Kort sagt: svarstypen står i förfrågans konstruktor, hos mottagaren. Kontrollen är *statiskt linjär men dynamiskt affin*. *Högst en gång* går att bevisa, och argumentet finns. *Minst en gång* går inte, i Ernest eller i något annat språk med generell rekursion, och den halvan bevakas av anroparen under körning.

## 1. Var svarstypen står

En process har en typad brevlåda, och en förfrågan är ett vanligt meddelande som bär ett `Reply(a)`, en engångsadress för svaret:

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))
```

`Get(reply : Reply(Int))` säger att en `Get` besvaras med en `Int`. Svarstypen hör till konstruktorn, inte till brevlådan, så ett protokoll kan blanda: `Get(reply : Reply(Int)) | Name(reply : Reply(String))`.

Anroparen och mottagaren kontrolleras mot samma fält, med vanlig Hindley-Milner-unifiering:

```
Address.call : (Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n
answer       : (Reply(a), a) -> Unit with m
```

```ernest
Address.call(counter, fn(reply) = Get(reply = reply), 1000)
```

`counter : Address(CounterMsg)` ger `m = CounterMsg`. Lambdan lägger `reply` i `Get`s fält, som har typen `Reply(Int)`, så `a = Int`, och anropet ger `Optional(Int)`. Hos mottagaren ger mönstret `Get(reply = reply)` typen `reply : Reply(Int)`, och `answer(reply, total)` kräver då `total : Int`.

Förfrågan är en funktion `(Reply(a)) -> m` och inte ett färdigt meddelande, eftersom det är `Address.call` som skapar det nya `Reply`: anroparen kan inte bygga `Get(reply = …)` före anropet.

**Varför svaret inte syns i anroparens brevlådetyp.** `n` i `with n` är anroparens egen brevlådetyp och är fri. Det är avsiktligt. Svaret går via en identifierare som är privat för anropet (en alias i Erlang) och aldrig via anroparens brevlåda. En process kan alltså anropa vilka tjänster som helst utan att deras svarstyper hamnar i dess eget protokoll, och även en process som inte tar emot något (`with Never`) kan göra anrop. Ett sent svar efter timeout kastas och kan inte dyka upp som ett meddelande av fel typ.

**Kedjor.** Typen följer med `Reply`-värdet. En mellanhand som skickar vidare `Get(reply = reply)` måste ha ett fält av typen `Reply(Int)` att lägga det i, så varje länk anger samma `a`. Det finns ingen adapter för `Reply`. En mellanhand som vill byta svarstyp måste själv besvara förfrågan, till exempel från en process den startar, som gör ett eget anrop och svarar med det omvandlade värdet.

Ett alternativ hade varit att lägga svarstyperna på mottagarens adresstyp, som CAF:s `replies_to<Get>::with<int>`. Det valdes bort eftersom protokollet då beskrivs av två typer som måste hållas överens. Priset är att man läser konstruktorn och inte adressen för att se vad en förfrågan ger.

## 2. Högst en gång: ja

Varje bindning av ett värde som innehåller ett `Reply`, ett *reply-bärande* värde, är en förpliktelse som ska förbrukas exakt en gång på varje väg från bindningen. Det förbrukas antingen av `answer` eller genom att lämnas vidare: skickas i ett meddelande, ges som argument, returneras, läggs i en konstruktor, en tupel eller en lista, eller fångas av en lambda som körs exakt en gång. Kontrollen görs per funktion och korsar inga anrop: en funktion som tar emot förpliktelsen kontrolleras vid sin egen definition.

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Get(reply = reply) -> count(total)
      | Inc(amount) -> count(total + amount)
    }
```

```
forgot.ern:5:9: the reply-carrying value reply is never consumed
4 |     receive {
5 |         Get(reply = reply) -> count(total)
  |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: a reply is consumed by answering it, passing it on once, or matching it (§6.6)
```

```ernest
type CounterMsg = Inc(Int) | Get(reply : Reply(Int))

fn twice(server : Address(CounterMsg), request : CounterMsg) : Unit with m = {
    send(server, request);
    send(server, request)
}
```

```
twice.ern:5:18: the reply-carrying value request is consumed twice
3 | fn twice(server : Address(CounterMsg), request : CounterMsg) : Unit with m = {
4 |     send(server, request);
  |                  ------- first consumed here
5 |     send(server, request)
  |                  ^^^^^^^
  | = help: a reply is consumed by answering it, passing it on once, or matching it (§6.6)
```

Det som gör kontrollen sund är att ett `Reply` inte kan kopieras eller tappas i det tysta:

- **Positioner.** Ett reply-bärande värde får bara stå där det flyttas. `==`, fältval och record update avvisas, och det gör även `_`, ett utelämnat fält och `as` i ett mönster. En toppnivåbindning av reply-bärande typ avvisas, eftersom alla funktioner kan läsa den.
- **Grenar.** Alla grenar i `if`, `match` och `receive` förbrukar samma förpliktelser. Kod som kan hoppas över, högerledet i `&&` eller `||` och det som följer en `<-`, får inte förbruka något som var öppet före den.
- **Closures.** En lambda som fångar en förpliktelse blir själv en förpliktelse och används exakt en gång: den anropas eller ges till `spawn`. En lokal namngiven `fn` kan anropas många gånger och får därför inte fånga någon.
- **Polymorfism.** En generisk definition läses en gång till, med typvariabeln antagen vara reply-bärande. Om den läsningen bryter disciplinen får variabeln restriktionen "inte reply-bärande", som skrivs ut `a!`: `dup : (a!) -> #(a!, a!)`, `List.size : (List(a!)) -> Int`. En instans med en reply-bärande typ avvisas vid anropet. En extra läsning räcker, eftersom kod som inte känner ett värdes typ bara kan flytta värdet.
- **Anrop som inte returnerar.** En funktion vars resultattyp är en variabel som varken parametrarna eller brevlådetypen nämner kan tas vid `Never`, och skulle då behöva skapa ett värde av en tom typ. Den returnerar alltså aldrig (parametricitet), och ett anrop till den, till exempel `fault`, förbrukar alla öppna förpliktelser. Det är 0-regeln i linjär logik: ur 0 följer vad som helst, med vilken kontext som helst.

Ur detta följer en invariant över hela körningen. En konfiguration är en mängd processer och en mängd obesvarade replies:

> **I3.** Ett obesvarat `r : Reply(τ)` förekommer högst en gång i konfigurationen: i en process uttryck, räknat genom de closures den håller, eller i ett meddelande.

Varje steg bevarar I3. `Address.call` skapar ett nytt `r` som bara finns i det skickade meddelandet. `send` flyttar det till ett meddelande, `receive` till klausulens bindningar och `spawn` till den nya processen. `answer` tar bort det. En krasch, en `kill` eller en `send` till en död process tar bort innehavaren, vilket I3 tillåter, eftersom den säger högst. Alltså besvaras inget `Reply` två gånger, och en funktion som returnerar har besvarat eller lämnat vidare varje `Reply` den fick.

## 3. Minst en gång: nej

Att `answer` faktiskt nås är en liveness-egenskap, och det kan inget typsystem avgöra i ett språk med generell rekursion. Det här accepteras, eftersom vägen förbrukar `reply`, men det svarar aldrig:

```ernest
fn spin() : Unit = spin()

fn count(total : Int) : Unit with CounterMsg =
    receive {
        Get(reply = reply) -> {
            spin();
            answer(reply, total)
        }
      | Inc(amount) -> count(total + amount)
    }
```

Samma sak händer om innehavaren kraschar eller dödas, eller om meddelandet ligger kvar i en brevlåda där ingen klausul matchar. En `receive` behöver inte täcka hela sin typ: ett meddelande som ingen klausul matchar blir liggande.

Den halvan sköts därför under körning, hos anroparen. `Address.call` har en obligatorisk deadline och ger `Optional(a)`, så att inget svar är ett fall programmet måste hantera. Anroparen övervakar mottagaren medan den väntar, så anropet slutar direkt om mottagaren dör, startas om eller blir onåbar. `Address.callForever` väntar utan deadline och kraschar i de fallen med mottagarens orsak.

Att få *minst en gång* statiskt kräver terminering, låsningsfrihet och fullständiga `receive`. Det är vad sessionstyper med progress-garanti ger, till exempel Caires och Pfenning, eller Wadlers *Propositions as Sessions*, till priset av begränsad rekursion och kommunikationstopologi. Ernest följer Erlang: en process får krascha och startas om, och den som väntar på ett svar har en deadline.

## 4. Hur formellt det är

Argumentet finns i [`docs/soundness.md`](https://github.com/joagre/ernest/blob/main/docs/soundness.md): en liten kalkyl, invarianterna (I3 är den för replies), att varje steg bevarar dem, och reply-reglerna i §6.5 till §6.8. Det är prosa och inte maskinkontrollerat. Mot koden hålls det av kompilatorns tester, ett fall per paragraf, och av en generator av typade program som ändrar förbrukningarna i program som kör: varje ändring måste kompilatorn avvisa.

Påståendet är falsifierbart. Ett program som kompilatorn accepterar och som besvarar ett `Reply` två gånger, eller tappar ett på en väg som returnerar, motbevisar det.

En mekaniserad version, med linjär kontextdelning och preservation för I3 över kalkylen, borde vara rimlig men finns inte. Tre steg är minst standard och de som jag skulle granska först:

1. att en extra läsning räcker för att härleda `a!`;
2. parametricitetsargumentet för anrop som inte returnerar;
3. lambdas bundna med `let` som förpliktelser.

Främmande kod (`foreign fn`) ligger utanför argumentet. Där är ett `Reply` en Erlang-alias som tar emot ett svar och kastar resten, så *högst en gång* gäller vad programmet gör, även där främmande kod inte håller sitt löfte. Mellan noder gäller I3 med alla noders processer som en enda konfiguration.

## Läsning

- Wadler, *Linear types can change the world!*, 1990.
- Wadler, *Theorems for free!*, 1989.
- Walker, *Substructural Type Systems*, i Pierce (red.), *Advanced Topics in Types and Programming Languages*, 2005.
- Honda, Vasconcelos och Kubo, *Language primitives and type discipline for structured communication-based programming*, ESOP 1998.
- Caires och Pfenning, *Session Types as Intuitionistic Linear Propositions*, CONCUR 2010.
- Wadler, *Propositions as Sessions*, ICFP 2012.
