# Ghost Core Arena

Canonical domain terms. Add a term when it first appears in code or design; list synonyms to avoid.

## Language

**Run**
One attempt in the Arena. Starts with an empty fleet: the player picks a faction and receives one
random starting ship from it. A Run is a sequence of Cycles.
_Avoid_: game, match, session

**Cycle** _(name under review: clashes with the campaign calendar's "cycle", a year)_
The Run's unit of time: one Shop visit followed by one fight.
_Avoid_: turn, round

**Shop**
Where the player spends Ghost Core Fragments on new ships between fights. Its offer is random and
weighted by Rarity.
_Avoid_: market, store

**Shop Tier**
The Shop's level. It rises a little every Cycle, and the player can pay Fragments to raise it
faster. A higher Tier offers rarer ships more often and raises the DP Limit.
_Avoid_: shop level, tavern tier

**Star Level**
A ship's Merge rank: ★1 base ship, ★2 from three ★1 (carries a level-2 officer), ★3 from three ★2
(carries a level-5 officer).
_Avoid_: rank, tier, grade

**Rarity**
A ship's class within its faction. It sets the ship's price and how often the Shop offers it.
_Avoid_: tier (reserved for Shop Tier), quality

**Endless**
Continuing a Run after its 10th win, with no win limit; it ends only on the last loss.
_Avoid_: infinite mode, free play

**Merge**
Combining three copies of the same ship into one stronger ship that carries an officer.
_Avoid_: fuse, combine, triple

**Bench**
Ships the player owns in a Run but keeps out of the fight, mothballed. They don't count against
the DP Limit and are never part of a Ghost Fleet.
_Avoid_: reserve, storage, hangar

**DP Limit**
The total deployment points the player's active (non-Bench) fleet may hold. Grows with Shop Tier.
_Avoid_: fleet cap, budget

**Ghost Core Fragment**
The Run's currency, spent in the Shop. Only exists inside a Run.
_Avoid_: credits, gold, points

**Ghost Fleet**
A frozen snapshot of another player's Run fleet at a given Cycle, fought under AI control. Never
live: its owner is not playing when you fight it.
_Avoid_: enemy fleet, PvP fleet, bot fleet

**Ghost Core**
The in-game AI that commands a Ghost Fleet in battle. Gives the mod its name.
_Avoid_: bot, AI opponent

**Ghost Core** _(item)_
The same core, taken home as the reward for winning a Run. Between an Alpha and a Beta core.

**Arena**
The place in the campaign where the player starts Runs. Shares its station with Slay the Sector's
Descent Relay when both mods are installed.

## Relationships

- A **Run** is a sequence of **Cycles**; each **Cycle** is one **Shop** visit then one fight.
- The player flies and commands their own fleet; a **Ghost Core** commands the **Ghost Fleet**.
- In Cycle N the player fights a **Ghost Fleet** recorded by another player at Cycle N.
- The player's fleet at each Cycle becomes a **Ghost Fleet** for others.
- **Rarity** and **Shop Tier** together decide what the **Shop** offers.
- Players only meet **Ghost Fleets** recorded with exactly the same mods.
- A Run ends at 3 losses or 10 wins; after 10 wins the player may go **Endless**.
- The **DP Limit** applies to the active fleet only; the **Bench** holds the rest.
