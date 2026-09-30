# Who is talking, and what are they saying?

The same fixture gives us two useful pieces of vocabulary:

```text
89 EA 06 53 57 2D 32 2E 31
```

## MID: who sent the message?

The first byte is the source MID:

```text
89 hex = 137 decimal
```

For this supported mapping:

> **MID 137 = Trailer Brakes #1**

A MID is a role/address on the network. It is **not a unique controller serial number**.

That distinction matters.

## PID: what information is being reported?

The next parameter in the fixture is:

```text
EA hex = 234 decimal
```

For this supported mapping:

> **PID 234 = Software Identification**

The following length byte is `06`, so six bytes belong to this parameter.

## Source is not destination

TFS treats source and request destination separately.

If a request is *addressed to* MID 137, that does not prove MID 137 answered.

For example:

```text
request → destination MID 137
```

means only:

> We observed a request directed at Trailer Brakes #1.

TFS requires an observed source MID before saying that controller actually transmitted a record.

That rule exists because a destination byte can otherwise look deceptively like evidence that a controller was present and talking.

## One more translation

```text
89 | EA | 06 | 53 57 2D 32 2E 31
```

becomes:

```text
MID 137          PID 234                  length 6       value
Trailer Brakes   Software Identification                  SW-2.1
```

The vocabulary is useful, but the plain-English meaning comes first.

**Next:** [What can TFS actually learn from messages?](WHAT_TFS_CAN_LEARN.md)
