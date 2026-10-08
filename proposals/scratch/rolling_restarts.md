# Rullande omstarter

Så här tänker jag.

Allt här förutsätter att kod är namngiven av sin hash. Varje definition får en hash av sitt innehåll. Det gäller funktioner, typer och toppnivåbindningar. Hashen är definitionens identitet överallt: i en spawn, i en nyckel och på ett meddelande. En typs identitet är alltså dess form, inte dess namn. Kod flyttar mellan noder genom hashen. Spawnar en process på en granne som saknar koden, så följer koden med. En nod kan till och med startas helt tom, utan något program alls: bara `ern` och en cache. Allt den kör kommer dit genom spawn från grannarna, med koden. Flera versioner av en definition kan stå sida vid sida på en nod. En process behåller koden den startades med tills den dör. Noder av olika releaser arbetar ihop. Och `ern diff` listar vilka definitioner som skiljer mellan två releaser.

Poängen är att Ernests kompilator redan vet det mesta som en operatör annars gissar sig till. Ponera att en "tjänst" är en namngiven, långlivad process som andra når genom dess adress. Typiskt en singleton, som en registrerad process i Erlang. En tjänst hittas via en nyckel. Nyckeln bär med sig typen på tjänstens brevlåda. Jämför man två releaser ser verktyget därför exakt vilka tjänster som fått ett ändrat protokoll. Det ser också vilka tillstånd som bytt typ. HM plus typade brevlådor gör sedan att en gammal klient och en ny tjänst aldrig möts av misstag. Den som söker tjänsten med fel identitet får `OtherType` tillbaka. Det blir ett planeringsfel i stället för en krasch i produktion.

Tre små tillägg i språket:

- `kept()`: en loop vars tillstånd runtime äger. Därför kan runtime be om tillståndet mellan två steg och skriva det till fil vid ett planerat stopp.
- `migrate()`: en medlem på den nya typen som gör ett nytt tillstånd av ett gammalt. Och en tillbaka, för återgång. Loopen kör den när den läser ett gammalt tillstånd.
- *adapterade adresser*: ett protokoll som fått nya konstruktorer erbjuds även under den gamla identiteten, via en ren konvertering. Ett protokoll som tagit bort en request får en liten forwarder i stället.

Ett förkortat exempel. Räknaren är en tjänst som håller en summa. En klient skickar `Add` med ett tal, eller `Get` med en reply och får summan tillbaka. Räknaren bor på noden *store*, och summan ska överleva en deploy. Loopen är en fold över brevlådan: tillståndet är ackumulatorn och varje meddelande ett element. `step` ger nästa tillstånd ur det förra och meddelandet. Den är utelämnad här, liksom det mesta annat.

    // counter.ern, release 1: protokollet, tillståndet och nyckeln klienterna hittar den på
    export type Msg = Add(Int) | Get(reply : Reply(Int))
    export type Count = Count(total : Int)
    export let key : Peer.Key(Msg) = Peer.key("counter")

    // store.ern, release 1
    //
    // restarting: kör loopen igen i samma process när den fallerar. Adressen består.
    // kept: runtime äger loopen och dess tillstånd. Vid ett planerat stopp ber runtime
    // om tillståndet mellan två steg och skriver det till fil. Nästa start läser filen
    // i stället för startvärdet, genom migrate om typen ändrats. En vanlig spawn
    // klarar sig förstås utan båda. Den börjar då om från noll när noden startar om.
    let counter : Address(Counter.Msg) =
        spawn(restarting(RestartLimit(restarts = 3, within = 5000),
                         kept(Counter.key, fn() = Counter.Count(total = 0), step)))

    export fn main() : Unit with Never = {
        Peer.offer(Counter.key, counter);
        wait()
    }

Release 2 lägger till `Reset` i protokollet och `adds` i tillståndet. Här är det som ändras. Och det som skrivs för att en gammal klient och en gammal tillståndsfil ska passa:

    // counter.ern, release 2. Samma modul, samma namn, samma nyckel. Identiteten är
    // formen, så ern diff ser båda ändringarna.
    export type Msg = Add(Int) | Get(reply : Reply(Int)) | Reset
    export type Count = Count(total : Int, adds : Int)
    ...

    // counter_v1.ern, release 2: den gamla formen och allt som hör till den, inklistrat
    // från ern diff. Filen tas bort i den release som släpper de gamla klienterna.
    export type Msg = Add(Int) | Get(reply : Reply(Int))
    export type Count = Count(total : Int)
    export let key : Peer.Key(Msg) = Peer.key("counter")

    // Så här ser migrate ut. ern diff skrev den. total matchade på namn och typ och
    // kopierades. adds är nytt och lämnades tomt. Luckan fylldes i för hand med 0.
    fn Counter.Count.migrate(old : Count) : Counter.Count =
        Counter.Count(total = old.total, adds = 0)

    // Och tillbaka, för återgång. adds faller bort.
    fn Count.migrate(new : Counter.Count) : Count = Count(total = new.total)

    // Gammalt meddelande in, nytt ut. En ren funktion. En borttagen request hade
    // behövt en liten forwarder-process i stället.
    export fn convert(message : Msg) : Counter.Msg = ...

    // store.ern, release 2: nyckeln erbjuds under båda identiteterna. En gammal
    // klient och en ny möts var och en på sin sida.
    Peer.offer(Counter.key, counter);
    Peer.offer(CounterV1.key, via(counter, CounterV1.convert));

Under täcket gör `kept()` så här. Loopen är runtimes egen, så runtime vet när den står mellan två steg. Vid ett planerat stopp drar noden först tillbaka sina nycklar. Den som söker tjänsten går då till en annan av nyckelns noder. Sedan dränerar noden väntande anrop, inom sin egen tidsgräns. Därefter ber den varje `kept`-loop om dess tillstånd mellan två steg. Tillståndet skrivs till en fil per nyckel, under `state/` i nodens konfigurationskatalog. Först hashen av tillståndstypens identitet, sedan värdet i samma kodning som ett värde korsar noder i. Filen skrivs under ett tillfälligt namn, syncas och döps om. Ett stopp som dör mitt i lämnar därför den gamla filen eller ingen. Sedan stänger noden och startar om sig själv i nästa release. Det sker i samma OS-process, så pid-filen står sig och service managern märker inget. Vid starten läser loopen under samma nyckel filen i stället för startvärdet. Hashen läses före värdet. Skiljer den sig från loopens egen typ går värdet genom `migrate`. Passar ingen `migrate` börjar loopen från startvärdet, vilket planen sa innan man sa ja. Filen tas bort först när noden lyssnar igen. En start som misslyckas lämnar den alltså kvar åt releasen som kommer tillbaka.

Och några kommandon i `ern`:

- `ern diff` jämför det noderna kör med den nya releasen och skriver ut planen. Den säger vad som ändrats och vad som vägras. Den skriver också ut själva `migrate`- och konverteringsfunktionerna, som text att klistra in, med luckor där ett beslut krävs. Verktyget rör aldrig källkoden.
- `ern deploy` gör rullningen. Först berättar den för varje nod vilken release som är nästa. Varje nod hämtar det den saknar från koordinatorn och kompilerar in det i sin cache på disk. Inget laddas in i den körande noden. En nod som inte kan ta emot koden, till exempel vid full disk, fäller planen innan något har stoppats. Operatören kopierar alltså ingen kod till någon nod. En tom nod är inte ens med i rullningen, eftersom inget av releasen är dess eget: det som redan kör där kör sin kod tills det dör, och nästa spawn från en omstartad granne tar med sig den nya koden. Sedan visar verktyget planen och väntar på ett ja. Frågan ställs först när varje nod håller hela releasen. Därefter stoppar den en nod i taget, i rätt ordning: tjänster före dem som anropar dem. Noden skriver sina tillstånd och startar om sig själv i nya releasen ur sin cache. Där kompileras inget, allt kontrolleras bara mot hasharna. Verktyget kollar att nycklarna svarar på rätt version och frågar igen innan nästa nod. Verktyget rullar aldrig tillbaka på egen hand. Inget händer utan ett ja. Det enda som installeras för hand på en maskin är `ern` själv, och en ny version av verktyget går därför inte genom rullningen.
- `ern status`, `ern state` och `ern test`: se vad som kör, läs en tillståndsfil, och kör hela rullningen som ett test. Testet körs på varje commit med genererade tillstånd. Oraklet är en round trip genom `migrate` fram och tillbaka.

Ett andra exempel, nu hela arbetsflödet. Ett team med ett tjugotal noder ska ge lagertjänsten ett extra fält i tillståndet och en ny request i protokollet.

1. Ändra typen och protokollet, bygg, kör `ern diff`. Planen säger två saker. Tillståndstypen under nyckeln `inventory` är ändrad och `migrate` saknas. Protokollet har en ny konstruktor och den gamla identiteten erbjuds inte. Den skriver ut båda `migrate`-funktionerna och konverteringen, färdiga så när som på det nya fältets startvärde.
2. Klistra in och fyll i luckan. Lägg den gamla typformen i `inventory_v1.ern` som diffen föreslår. Erbjud nyckeln även under gamla identiteten. Kanske tjugo rader totalt.
3. Kör `ern test` med gamla och nya releasen. Grönt.
4. Kör `ern deploy`. Planen visar ordningen: noderna som erbjuder `inventory` först, sedan klienterna. Noder vars kod inte ändrats hoppas över. Varje nods dräneringstid visas, och summan. Säg ja. Titta på första noden en stund. Säg `all`.
5. Nästa sprint: ta bort `inventory_v1.ern` och det gamla erbjudandet. Planen vägrar om någon nod fortfarande kör en release som behöver det. Annars går det igenom. Expand then contract, fast verktyget håller en i örat.

Så här kan det se ut i en terminal. Påhittat, men i den form verktygen är tänkta att skriva. Lagertjänsten heter `inventory` och dess tillstånd `Stock`. Nyckelns noder är *store1* och *store2*. *web1* till *web18* är klienter, och *batch* är ett program i samma release som inte körs just nu. Rader som börjar med $ är vad operatören skriver, resten är vad verktygen svarar:

    $ ern build
    release 42 built: 61 modules, 3 entry points

    $ ern diff build --config-dir ops
    release 41 to release 42
      inventory.ern   changed   Msg, Stock, step
      orders.ern      follows   placeOrder
      inventory       protocol added Reserve        refused: not offered at release 41's identity
                      state changed: Stock to Stock refused: Stock.migrate missing
    to write, from the matching fields and constructors:

    // inventory_v1.ern: the shape release 41 runs
    export type Msg = Get(sku : String, reply : Reply(Int)) | Add(sku : String, count : Int)
    export type Stock = Stock(items : Map(String, Int))
    export let key : Peer.Key(Msg) = Peer.key("inventory")

    fn Inventory.Stock.migrate(old : Stock) : Inventory.Stock =
        Inventory.Stock(items = old.items, reserved = )
    fn Stock.migrate(new : Inventory.Stock) : Stock = Stock(items = new.items)

    export fn convert(message : Msg) : Inventory.Msg =
        match message {
            Get(sku = sku, reply = reply) -> Inventory.Get(sku = sku, reply = reply)
          | Add(sku = sku, count = count) -> Inventory.Add(sku = sku, count = count)
        }

    $ $EDITOR src/inventory_v1.ern    # klistra in, fyll i luckan: reserved = Map.empty
    $ $EDITOR src/store.ern           # erbjud nyckeln under gamla identiteten med via
    $ ern build
    release 42 built: 62 modules, 3 entry points

    $ ern test --config-dir ops release-41 build
    plan: accepted
    inventory: 200 states of release 41 through Stock.migrate and back: equal
    rollout on two nodes, and the way back: ok

    $ ern deploy build --config-dir ops
    release 42 fetched into every node's cache: store1, store2, web1 .. web18 hold it whole
    plan: release 41 to release 42
      store1, store2, web1 .. web18: ern 1.2.0, scheme 1
      inventory       protocol added Reserve        served at release 41's identity through
                                                    InventoryV1.convert, until the release
                                                    that drops inventory_v1.ern
                      state changed: Stock to Stock Stock.migrate, and the way back
    order: store1, store2; web1 .. web18; batch not running
    each node's time: 60 s; the rollout takes at most 20 min
    the way back: ern deploy release-41 --config-dir ops
    meanwhile: a send to inventory during a store's restart is dropped; a call answers None
    yes? yes
    store1: keys withdrawn, drained in 3 s, inventory written, 1.8 MB, restarted,
            inventory found at release 42
    next or all? next
    store2: keys withdrawn, drained in 2 s, inventory written, 1.8 MB, restarted,
            inventory found at release 42
    next or all? all
    web1 .. web18: restarted, checked
    release 42 on every node; the way back: ern deploy release-41 --config-dir ops

Måste man backa mitt i, kör man `ern deploy` med förra releasen. Den ligger kvar i varje nods cache tills planen sagt att ingen väg tillbaka når den. `migrate` tillbaka ligger i den nyare releasen. Noden skriver därför tillståndet i gammalt format redan vid stoppet.

Det teamet skriver är bara det ingen maskin kan veta: vad ett nytt fält ska innehålla och vad en borttagen request ska svara. Resten räknar verktyget ut.
