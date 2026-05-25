# WeakAura Hello-World import diagnostic

Three progressively-different WA strings to isolate **where** our import flow is failing. Try them in order.

For each one, paste into WeakAuras (`/wa` → `+ New` → `Import`) and report:
- ✅ **WORKS** — Import preview dialog appears with an Import button
- ❌ **FAILS** — paste accepted but no preview dialog opens (or "very old" / invalid string warning)

---

## TEST 1 · `WAGO_VERBATIM`

The Wago WA you previously confirmed works, re-encoded by our parser library with **zero content changes**. This isolates whether the parser itself is corrupting bytes on encode/decode.

- ✅ → parser is fine; issue is in our schema template
- ❌ → parser library is broken; we need a different encoder

```
!WA:2!fsv3UnnmyunajqDOjaHMeBxGvKyAtI1U2ngAtQc1FYMk01wsZ2exvCsCs8iXoy7STonXf7kUL(i0hHkH4EEcQ4rGhbEcWojBvRdXCUiXF(C(S95CANzPN481NZ6321LJe1NLrJfbycI1EFZMnAPZogX4yk5(g20ak7T3voyNMIEMQUuIi6r7WWNbEFm0HbfqGP5FWebIrGbhKY97gNGDe(37PwNa9OnQp44IMNCyxV99hWrbUDOs8w10BzQBmcsS9PSKsJNJDumxGD7pEUsXSGOf9fIi(2fkOAtEmTWv9PW6LIXodp6vf361EFUy)J(fmwi7t7iHC)55gkO2zxKh05zd5XwgiVKvg5G5rbW(MOtfAVOOfNgZSrw4Wiktm0MsCWzTWwEwOHkCNENfDJj2Q6lVsoaiGAddaWimOmO3U5RWqeynk023SAn5YyxaHkswx4JiagseZiannaI4Cf9qQdcaKDqIl)UiXEY5lVcGYKaVcKaY8qIjG6WWHqwFZKYTGHzm(xRwlaY53OHktnMjB4Yj7F5YaT31Oztn5jbsCaANB7khB4SHJMIQK3uJj86EyLotXBRTwBTBLxD9D0BvxBcVn30QKR7TYRDh9wtTFkUAPxrvbR1vpAPwqM09LYkHx5dj9oZlYKH85tTb5BTZzBd0uFLsuIo1T(Fm0YjX87igYfXmP7h5afi)HSKOMz)iuvHm9yXrHYSOrX8RLVu1ak0zNbXCupBLb5N8jbjb4xLJpdnVryCGapVbuLQ(4WeK0qlOW3sMoDXE5UqWWEEY09clniMKnzER08A0ctIQxE2fSyK62WYWEW4vJ(21s0zr2PdZxl)6cd4OBgHV5pbMKMNiFjqLEbbhKyGxoxZqVRUzIoAjfbIGh9MonR8bDJEg67Q3Qx9gDRuTPE9xcUwz9wzvRuRMSuT27TNmuvXSr7wvfsLF8QJs1JEQzwCbueZnS9r2FYizF0Worpwsg8ZFauhwGf0XdnctCPSqOsyYz5JWE(c4fQ)1RR0BAmE2Xp8V
```

---

## TEST 2 · `WAGO_TEXT_TWEAK`

Same WA as TEST 1, with `id` changed to `ACC Hello World` and `displayText` changed to `Hello World`. Custom logic stripped. Tests whether modifying any field breaks the validation.

- TEST 1 ✅ + TEST 2 ✅ → small mutations to a working WA still import; issue is bigger schema differences
- TEST 1 ✅ + TEST 2 ❌ → WA's import validator hashes the original payload (signed integrity check), so we can't reuse the Wago WA at all

```
!WA:2!Lj5ZUnrmqyCXFKaLIQqiuLOCaREOcKOjKIqiqQcLnzBjO2KYMTTItbVR9URlETxgpUTPh4qpXvYJqEeIeVhr8iWJqFcW7Mqbe(KNXFF)MXJ91w)ESV(iyu)Kedh7SeOTOuO4q)dc3TBpF4eoyeA1TcI1sn8UB4wWzZvFnVeTclU72G4CY7Tugqrkjm8sHc5GIkpCU3VhCQGHz38(rNst1D7m(KMHNE0G0dYgB4YK91o9rT97f6hmLQIZ0qvQzldhBnOiz0SL30cYIhMHyH51nAuIPUq34konE(MwbBYXVO5REz6NBo64FqTOJt)c0vFtTjOoEXf527)GjgBuapT6KPmHPqshfYpdN(wUuQjhPbjlYOTqmpsKxObCsSwXelyf7AkDEPHR)ZcGNWHq9bfmkYZMavydhvW9qNGidp3v3GM1Fw9n9KAkB7XwdFySKAmzvBvCNGmpJ4C(kb5wjkwjGcCf9JtQuQZJOywKRbseP1UabrAQ7MS66JTQfbRenVLkwnXQIl7Yh)ecWrlOiiy5eUIbl0E4Snk(2FKvJqejeLgjd3PERYY2wtJZc9AtWmU63usOstfgNEPoMkj5AgNS1)5Q(oCCp3rvKxyUs6x2IOescvXUkETa)b(HRvZHnYneuOP4n7VBRp4hmmWFh)Ed70DqlVD978uY)K2V3ISTA32LQD)92ZVxNwHD73ZdDt(zBmD(8yyzuKbPO1eeNXJ)uqvDwtWU05L8xp3tfQenKtlNk1IY4I0mKEr537bUhMUZwA2D(fa
```

---

## TEST 3 · `SCRATCH_MINIMAL`

Built from scratch in **the same code path our `export_weakauras.mjs` exporter uses** (the one generating the 5 Mode badge / Burst gate / etc. templates). If TEST 1+2 work but THIS fails, then our exporter is missing or mis-shaping a field that the working Wago WA includes. We'll diff the two and fix.

```
!WA:2!LfvtUnrmuy1YcqrSarLIeLfmQlGwvPKsvfcXUoHerqOMYW0UTX2ZBg7IhB3NFUPPlRybRZrihHiX9OIJahHEcWzswbEJ)83779JFFB0(5f)8v7OkCBDCVEjFc0ABYUEbYiHCVddQIf2JSx)UJQUK9(Y5iuPSM8PoiLGBOffkVtZMMhXp8p5oxe8KTEzOn5EO(AaZoOZbDElgr(yvE8dkdbOHPpFfXVMtwX6Gp50xW92akaUQ2zr6ocvvvXGB)ACnCqkfhe(Q(Sy11fnuEIrbFMqcIVZdUcgb3VLB7YGrqXIV7Ejiqb0KqyasatXSGzDrBhf(Y)xyjt7BuMQTSIbZcE4cHM59YgObIZTCEdRTMZizQxDl0oRoOj15zmemSX7WRgN5yinDCkYufJt9wTDmxynLQQwluMslwZw25w)MfiPfh5w(Y3AEutHAn2h4zngHV1cMreLDQnUl596FsE)SzEqx2qC)(4nJkl9aTboDniteBj(5hfpPLwd5E2auDBYxdSIOVXsYZVBj93It)q0giTYa4OZY)YWt6Jxg3XQYP3VF2evbj)Xt5sqvjj4WaQDVrsKZ)HUDRuKmW7e3eDJwYvtcDpE5)VNLjK5P94tyv2HFCZ)4qOeWC7znoK8V
```

---

## How to use this file

After cloning / pulling the repo:

```bash
# Read this file from the local file system to copy strings cleanly
cat docs/wa-hello-test.md
```

Each TEST string is on its own line inside a ```` ``` ```` block — your editor / file manager won't truncate or wrap them like a chat UI might.

Or read raw on GitHub: https://raw.githubusercontent.com/tomqwu/ArenaCoachTBC/main/docs/wa-hello-test.md

The strings can be regenerated at any time:

```bash
node tools/test_hello_wa.mjs > /tmp/hello-out.txt
```
