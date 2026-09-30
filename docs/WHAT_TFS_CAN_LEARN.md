# What can TFS actually learn from messages?

TFS intentionally supports a small subset of J1587 today.

The goal is not to decode everything. The goal is to make supported observations reproducible and to keep unsupported material from turning into invented identity.

## Supported observations

| PID | TFS treatment | Identity role |
| ---: | --- | --- |
| 192 | Multisection transport; reassemble before decoding the enclosed parameter | Transport mechanism, not identity itself |
| 234 | Software Identification | Metadata about a controller |
| 237 | VIN payload, when present | Optional evidence; does not prove physical ownership by itself |
| 243 | Component Identification | Can provide component MID plus make/model/serial fields |
| 245 | Total Vehicle Distance | Telemetry only; not an identity anchor |
| 254 | Vendor-specific escape traffic | Preserved as opaque evidence; **not decoded as a serial** |

## Component observations

A component-identification observation can contain information such as:

```text
controller role
manufacturer
model
serial
software
```

TFS can normalize that into a component observation.

But a component observation answers:

> **What electronic module did we observe?**

It does not automatically answer:

> **Which physical trailer is this?**

## Optional VIN

When a supported VIN payload is present, TFS can retain it.

VIN is deliberately optional in the TFS identity model. The project is not designed around requiring a driver to type or scan one.

A reported VIN is still evidence that must be interpreted in context rather than treated as magical proof of ownership.

## Telemetry stays telemetry

TFS can retain supported distance data, but it does not promote that telemetry into a primary identity anchor.

That separation keeps "useful data" from quietly becoming "identity evidence."

## Proprietary traffic stays opaque

PID 254 is especially important.

TFS can retain the exact raw frame as vendor-specific evidence while saying:

> **We do not yet know what these bytes mean.**

That is a successful outcome.

Preserving an unknown is better than confidently mislabeling it.

**Next:** [Why isn't one controller the trailer?](CONTROLLER_IS_NOT_THE_TRAILER.md)
