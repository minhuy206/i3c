Specification for
I3C Transfer Command Response Interface
(MIPI I3C TCRISM)
Version 1.0
24 May 2022
MIPI Board Adopted 7 September 2022
Public Release Edition
Further technical changes to this document are expected as work continues in the
Software Working Group.
Copyright © 2022 MIPI Alliance, Inc.

Specification for I3C TCRI Version 1.0
24-May-2022
NOTICE OF DISCLAIMER
The material contained herein is provided on an “AS IS” basis. To the maximum extent permitted by
applicable law, this material is provided AS IS AND WITH ALL FAULTS, and the authors and developers
of this material and MIPI Alliance Inc. (“MIPI”) hereby disclaim all other warranties and conditions, either
express, implied or statutory, including, but not limited to, any (if any) implied warranties, duties or
conditions of merchantability, of fitness for a particular purpose, of accuracy or completeness of responses,
of results, of workmanlike effort, of lack of viruses, and of lack of negligence. ALSO, THERE IS NO
WARRANTY OR CONDITION OF TITLE, QUIET ENJOYMENT, QUIET POSSESSION,
CORRESPONDENCE TO DESCRIPTION OR NON-INFRINGEMENT WITH REGARD TO THIS
MATERIAL.
IN NO EVENT WILL ANY AUTHOR OR DEVELOPER OF THIS MATERIAL OR MIPI BE LIABLE TO
ANY OTHER PARTY FOR THE COST OF PROCURING SUBSTITUTE GOODS OR SERVICES, LOST
PROFITS, LOSS OF USE, LOSS OF DATA, OR ANY INCIDENTAL, CONSEQUENTIAL, DIRECT,
INDIRECT, OR SPECIAL DAMAGES WHETHER UNDER CONTRACT, TORT, WARRANTY, OR
OTHERWISE, ARISING IN ANY WAY OUT OF THIS OR ANY OTHER AGREEMENT RELATING TO
THIS MATERIAL, WHETHER OR NOT SUCH PARTY HAD ADVANCE NOTICE OF THE
POSSIBILITY OF SUCH DAMAGES.
The material contained herein is not a license, either expressly or impliedly, to any IPR owned or controlled
by any of the authors or developers of this material or MIPI. Any license to use this material is granted
separately from this document. This material is protected by copyright laws, and may not be reproduced,
republished, distributed, transmitted, displayed, broadcast or otherwise exploited in any manner without the
express prior written permission of MIPI Alliance. MIPI, MIPI Alliance and the dotted rainbow arch and all
related trademarks, service marks, tradenames, and other intellectual property are the exclusive property of
MIPI Alliance Inc. and cannot be used without its express prior written permission. The use or
implementation of this material may involve or require the use of intellectual property rights (“IPR”)
including (but not limited to) patents, patent applications, or copyrights owned by one or more parties,
whether or not members of MIPI. MIPI does not make any search or investigation for IPR, nor does MIPI
require or request the disclosure of any IPR or claims of IPR as respects the contents of this material or
otherwise.
Without limiting the generality of the disclaimers stated above, users of this material are further notified that
MIPI: (a) does not evaluate, test or verify the accuracy, soundness or credibility of the contents of this
material; (b) does not monitor or enforce compliance with the contents of this material; and (c) does not
certify, test, or in any manner investigate products or services or any claims of compliance with MIPI
specifications or related material.
Questions pertaining to this material, or the terms or conditions of its provision, should be addressed to:
MIPI Alliance, Inc.
c/o IEEE-ISTO
445 Hoes Lane, Piscataway New Jersey 08854, United States
Attn: Managing Director
ii Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
Contents
Figures ............................................................................................................................................. v
Tables .............................................................................................................................................. vi
Release History ............................................................................................................................ vii
1 Introduction ............................................................................................................................ 1
1.1 Scope .................................................................................................................................................... 1
1.2 Purpose ................................................................................................................................................. 1
2 Terminology ............................................................................................................................ 2
2.1 Use of Special Terms ............................................................................................................................ 2
2.2 Definitions ............................................................................................................................................ 2
2.3 Abbreviations ....................................................................................................................................... 5
2.4 Acronyms ............................................................................................................................................. 5
2.5 Color Coding ........................................................................................................................................ 7
3 References ............................................................................................................................... 8
4 Technical Overview ................................................................................................................ 9
4.1 Scope .................................................................................................................................................. 10
4.2 I3C TCRI Purpose .............................................................................................................................. 11
4.3 I3C TCRI Key Features ...................................................................................................................... 12
4.4 I3C TCRI Fundamental Principles ..................................................................................................... 13
4.5 I3C TCRI Relationship to Other MIPI Specifications ........................................................................ 14
5 Architectural Overview (informative) ................................................................................ 15
5.1 Transfer Command/Response Interface Architecture ......................................................................... 15
5.2 General Information ........................................................................................................................... 16
5.3 Target Device Support Model ............................................................................................................. 16
5.3.1 I3C Devices ....................................................................................................................................16
5.3.2 I2C Devices.....................................................................................................................................16
6 Theory of Operation............................................................................................................. 17
6.1 Device Management and I3C Addressing........................................................................................... 18
6.1.1 Device Attach, Enumeration, and Initialization ..............................................................................18
6.1.2 Device Addressing..........................................................................................................................18
6.2 Transfer Command Handling ............................................................................................................. 19
6.2.1 Target Device Requirements ..........................................................................................................20
6.2.2 Response Descriptor Generation ....................................................................................................20
6.2.3 Automatic Entry and Exit for HDR Modes ....................................................................................20
6.2.4 Sequences of Transfer Commands .................................................................................................21
6.2.5 Speed and Mode Changes Within A Sequence ...............................................................................23
6.2.6 Support for I3C In-Band Interrupts ................................................................................................25
6.2.7 Support for I3C ‘Short’ Read-Type Transfers .................................................................................26
6.3 Managed CCC Transfer Framing Model ............................................................................................ 27
6.3.1 Direct CCC Framing with Multiple Segments in a Transfer...........................................................29
6.3.2 Mixing Direct and Broadcast CCCs ...............................................................................................35
6.3.3 Error Handling for CCC Flows ......................................................................................................36
6.3.4 Mixing CCCs and Private Read/Write Transfers ............................................................................37
6.3.5 Support for HDR Modes ................................................................................................................38
6.4 Error Handling .................................................................................................................................... 40
6.4.1 Error Status Codes in Response Descriptor ....................................................................................40
6.4.2 Errors Due to Command Sequence Stall or Timeout ......................................................................46
Copyright © 2022 MIPI Alliance, Inc. iii
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
7 Transfer Command/Response Structures .......................................................................... 49
7.1 Format 1: Legacy Format, Indexed..................................................................................................... 50
7.1.1 Common Aspects of Transfer Commands ......................................................................................50
7.1.2 Command Descriptor .....................................................................................................................53
7.1.3 Response Descriptor .......................................................................................................................68
7.2 Format 2: Legacy Format, Direct Addressed ...................................................................................... 70
7.2.1 Common Aspects of Transfer Commands ......................................................................................70
7.2.2 Command Descriptor .....................................................................................................................72
7.2.3 Response Descriptor .......................................................................................................................87
Annex A Implementation Guidance ....................................................................................... 89
A.1 Application Capability Reporting ....................................................................................................... 89
A.2 Support for DAT-based and Direct Transfer Commands (Format 1 and Format 2) ............................ 90
Participants ................................................................................................................................... 91
iv Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
Figures
Figure 1 Color Coding Scheme ......................................................................................................................................... 7
Figure 2 I3C System Overview ......................................................................................................................................... 9
Figure 3 Example TCRI Integration with I3C Bus Controller Logic ...............................................................................15
Figure 4 Direct CCC Framing Model ..............................................................................................................................27
Figure 5 Broadcast CCC Framing Model ........................................................................................................................27
Figure 6 Support for Direct CCC Commands Framing Model ........................................................................................31
Figure 7 Direct CCC Commands Framing Model: Example 1 ........................................................................................32
Figure 8 Direct CCC Commands Framing Model: Example 2 ........................................................................................33
Figure 9 Direct CCC Commands Framing Model: Example 3 ........................................................................................33
Figure 10 Direct CCC Commands Framing Model: Example 4 ......................................................................................34
Figure 11 Overview of Supported Command Types for Command Descriptor, Format 1 ...............................................54
Figure 12 I3C Bus Activity for Combo Transfer ..............................................................................................................63
Figure 13 Overview of Supported Command Types for Command Descriptor, Format 2 ...............................................73
Figure 14 I3C Bus Activity for Combo Transfer ..............................................................................................................82
Copyright © 2022 MIPI Alliance, Inc. v
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
Tables
Table 1 Error Status Codes in Response Descriptor .........................................................................................................40
Table 2 Command/Response Formats ..............................................................................................................................49
Table 3 Supported I3C Transfer Modes ...........................................................................................................................50
Table 4 Maximum Values for I3C SDR Data Transfer Speeds .........................................................................................51
Table 5 Maximum Values for I2C Data Transfer Speeds ..................................................................................................51
Table 6 Supported Command Types for Command Descriptor, Format 1 ........................................................................53
Table 7 Immediate Data Transfer Command Structure ....................................................................................................55
Table 8 Immediate Data Transfer Command Usage for CCCs and Defining Bytes .........................................................58
Table 9 Regular Data Transfer Command Structure ........................................................................................................59
Table 10 Combo (Write + Write/Read) Transfer Command Structure .............................................................................64
Table 11 Response Descriptor Structure ..........................................................................................................................68
Table 12 Supported I3C Transfer Modes .........................................................................................................................70
Table 13 Maximum Values for I3C SDR Data Transfer Speeds .......................................................................................71
Table 14 Maximum Values for I2C Data Transfer Speeds ................................................................................................71
Table 15 Supported Command Types for Command Descriptor, Format 2 ......................................................................72
Table 16 Immediate Data Transfer Command Structure ..................................................................................................74
Table 17 Immediate Data Transfer Command Usage for CCCs and Defining Bytes .......................................................77
Table 18 Regular Data Transfer Command Structure ......................................................................................................78
Table 19 Combo (Write + Write/Read) Transfer Command Structure .............................................................................83
Table 20 Response Descriptor Structure ..........................................................................................................................87
Table 21 Guidance on CMD_ATTR Values for Command Descriptor Formats 1 and 2 ..................................................90
vi Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0  Specification for I3C TCRI
24-May-2022
Release History

| Date         | Version                               | Description  |     |
| ------------ | ------------------------------------- | ------------ | --- |
| 07-Sep-2022  | v1.0  Initial Board adopted release.  |              |     |

|     | Copyright © 2022 MIPI Alliance, Inc.  |     | vii  |
| --- | ------------------------------------- | --- | ---- |
  Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
This page intentionally left blank.
viii Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
1 Introduction
1 The proliferation of sensors in mobile wireless and mobile-influenced products has created significant design
2 challenges. The number of sensors in platforms increases each year, and sensors are becoming crucial for
3 enabling new use cases and for platform power management.
4 The standardization of interfaces and common software support allow for more reliable hardware and
5 software. In platform design, the use of common components allows designers to focus efforts on actual
6 sensor applications, rather than the interfaces.
7 If no consistent method for interfacing to I3C were available, then every platform vendor would be faced
8 with designing and enabling their own interface to support I3C. In addition to the main interface other signals
9 may be needed, such as dedicated interrupts, chip select signals, and enable and sleep signals. This increases
10 the required number of Host GPIOs, and that in turn drives up system cost with more Host package pins and
11 more PCB layers. As time passes and the number of sensors increases, this becomes increasingly difficult to
12 support and manage.
13 The MIPI I3C interface has been developed to ease sensor system design architectures in mobile wireless
14 products by providing a fast, low cost, low power, two-wire digital interface for sensors. I3C is compatible
15 with existing Legacy I2C Devices, with feature limitations. I3C defines the idea of Controller Devices and
16 Target Devices (i.e., I3C Devices with the role of Controller and/or Target). I3C also allows for multiple
17 Controller-capable Devices (i.e., one Primary Controller and optionally one or more Secondary Controllers)
18 in the Bus topology.
19 This I3C TCRI Specification describes the Transfer Command/Response Interface exposed by hardware
20 implementing I3C Controller Devices, i.e., the I3C Controller Interface for driving transfers on an I3C Bus
21 with the MIPI I3C protocol [MIPI02].
1.1 Scope
22 This Specification contains sufficient detail to develop a compliant lower-level (i.e., peripheral) layer for any
23 device that includes an I3C Controller, for use as part of an Application that can send Transfer Commands
24 and receive Transfer Responses using the defined formats in this Specification. It includes an Architectural
25 Overview, the Theory of Operation, and definitions of the data structures that define the I3C Controller’s
26 interface with its Application. However, this Specification alone does not provide sufficient detail to develop
27 the entire Application, which may have additional capabilities beyond this Transfer Command/Response
28 Interface.
29 The reader is assumed to be familiar with the I3C Specification [MIPI02]. Concepts described in the I3C
30 Specification will not be repeated here, except where necessary for proper understanding.
1.2 Purpose
31 The purpose of this Specification is to standardize the Transfer Command and Transfer Response interface
32 for I3C Controller hardware, which can be integrated into any Application. This allows multiple I3C
33 Applications to use the same data structures for interfacing with I3C Controller hardware.
34 The target audience of the document are developers of Active Controller (I3C Controller) hardware, and
35 developers of I3C Applications.
Copyright © 2022 MIPI Alliance, Inc. 1
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
2 Terminology
2.1 Use of Special Terms
36 The MIPI Alliance has adopted Section 13.1 of the IEEE Standards Style Manual, which dictates use of the
37 words “shall”, “should”, “may”, and “can” in the development of documentation, as follows:
38 The word shall is used to indicate mandatory requirements strictly to be followed in order
39 to conform to the Specification and from which no deviation is permitted (shall equals is
40 required to).
41 The use of the word must is deprecated and shall not be used when stating mandatory
42 requirements; must is used only to describe unavoidable situations.
43 The use of the word will is deprecated and shall not be used when stating mandatory
44 requirements; will is only used in statements of fact.
45 The word should is used to indicate that among several possibilities one is recommended
46 as particularly suitable, without mentioning or excluding others; or that a certain course of
47 action is preferred but not necessarily required; or that (in the negative form) a certain
48 course of action is deprecated but not prohibited (should equals is recommended that).
49 The word may is used to indicate a course of action permissible within the limits of the
50 Specification (may equals is permitted to).
51 The word can is used for statements of possibility and capability, whether material,
52 physical, or causal (can equals is able to).
53 All sections are normative, unless they are explicitly indicated to be informative.
2.2 Definitions
54 a priori: Knowledge resulting from theoretical deduction, not from observation or experience (Latin).
55 ACK: Short for “acknowledge”. See also NACK.
56 Active Controller: The I3C Device that presently has Controller control of the I3C Bus.
57 Address Arbitration: Process for determining arbitrated Addresses to resolve contention.
58 Address: A set of bits designating a Device.
59 Application: A Host or controlling entity that implements this I3C Transfer Command/Response
60 Specification and provides I3C Controller functionality.
61 Arbitrable: Subject to decision by Arbitration.
62 Arbitration: If two Devices start transmission at the same time, then Arbitration is required to determine
63 Bus control. Arbitration could also be required during a Target transmission if a Controller addresses multiple
64 Target Devices. Arbitration is required when a Controller sends an address and when a Target sends an In-
65 Band Interrupt.
66 Atomic (Relating to an operation or transaction): A sequence comprising a set of smaller operations, provided
67 in a particular order, which must either be executed fully from start to finish without interruption; executed
68 in part (if applicable to the sequence), stopping only at designated safe points of interruption, and not allowed
69 to continue after any such interruption, due to unintended consequences that would induce behavior different
70 from that which would be induced by continuous execution; or cancelled entirely after any such interruption.
71 In cases of an interruption, any subsequent smaller operations that might not have been executed after the
72 interruption (e.g., when some smaller operations were not yet received before the determination of the end
73 of the sequence was known) must either be nullified or not executed.
74 Broadcast: Refers to an Address or command that is transmitted to multiple Target Devices.
2 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
75 Characteristics: Quantification of a Device’s available features and capabilities.
76 Combo: A two phased transfer operation, typically consisting of the combination of two transfers as a single
77 unit. Usually structured as either a Write + Write operation, or a Write + Read operation. The transfers for
78 these phases might be separated by specific framing specific to the I3C Mode(s) used for each phase.
79 Typically, the first phase is a shorter transfer which informs a Device to prepare for the second phase.
80 Command Descriptor: Structure used to define I3C Command, CCC or Transfer.
81 Common Command Codes (CCC): Globally supported commands to be transmitted either directly to a
82 specific I3C Target Device or to all I3C Target Devices simultaneously.
83 Controller: A reference to the I3C Bus Device that is controlling the Bus.
84 Controller Logic: An internal component comprising dedicated logic and internal transfer mechanisms,
85 integrated within the I3C Controller, that acts as the Controller of the I3C Bus in Active Controller mode.
86 Typically contains internal FIFOs, clock logic, status, and other interfaces under the control of the I3C
87 Controller to process Transfer Commands from the Command Queue, handle Interrupt Requests and perform
88 other necessary tasks in the role of Active Controller.
89 Controller-role: Control of the I3C Bus, in an Active Controller role.
90 Device: A Controller or Target.
91 Device Address Table: Table that contains information on Target Devices addressable on the I3C Bus.
92 Device ID: Defines a Device’s characteristic or function within a sensor system.
93 DWORD: A 32-bit data word.
94 Dynamic Address: A Device Address that is assigned or allocated during initialization of the I3C Bus, or
95 subsequently as needed. Usually occurs after power up.
96 Frame: A Frame begins with a START, followed by the Address of the targeted Target(s), Data, and finally
97 a STOP.
98 HCI: Host Controller Interface that implements this I3C Transfer Command/Response Interface and also
99 meets the requirements of the I3C Host Controller Interface Specification [MIPI05].
100 HDR-DDR: HDR Double Data Rate
101 HDR-BT: HDR Bulk Transfer
102 High Data Rate (HDR): High Data Rate modes that achieve higher speed by transferring data on both clock
103 edges.
104 High: A signal level of logical “1”.
105 Hot-Join: Target Devices that join the Bus after it is already started, whether because they were not powered
106 previously or because they were physically inserted into the Bus; the Hot-Join mechanism allows the Target
107 to notify the Controller that it is ready to get a Dynamic Address.
108 In-Band Interrupt: Interrupt from Target Device on I3C Bus without a separate pin connection.
109 I2C Device: A Controller or Target that meets the requirements of the I2C Specification [NXP01].
110 I3C Bus: The physical and logical implementation of the SCL and SDA lines according to I3C Specification
111 [MIPI02].
112 I3C Device: A Controller or Target that meets the requirements of the I3C Specification [MIPI02].
113 I3C Bus Controller Logic: See Controller Logic.
114 I3C Target: See Target.
115 Legacy I2C: I3C maintains the industry standard architecture of I2C and supports existing I2C Target Devices.
116 I3C does not support I2C Bus Controllers.
117 Low: A signal level of logical “0”.
Copyright © 2022 MIPI Alliance, Inc. 3
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
118 Message: A packetized communication between Devices.
119 MIPI Manufacturer ID (MID): A two byte (16 bit) unique identifier for a vendor of a MIPI compliant
120 Device [MIPI01].
121 Mode: I3C defined data transfer methods, namely: Legacy I2C Mode; Single Data Rate Mode (SDR); and
122 various High Data Rate (HDR) Modes including Dual Data Rate Mode (HDR-DDR), Bulk Transfer Mode
123 (HDR-BT), Ternary Symbol Legacy Mode (HDR-TSL), and Ternary Symbol for Pure Bus Mode (HDR-
124 TSP).
125 Multi-Drop: A Bus that communicates through a process of Arbitration to determine which Device sends
126 information at any point. The other Devices listen for data they are intended to receive.
127 NACK: Short for “not acknowledge”, which means No ACK was asserted. See also ACK.
128 Open-Drain: High-Z with an active Pull-Down. Typically used in conjunction with a passive Pull-Up.
129 Primary Controller: Controller that has overall control of the I3C Bus, including control and handoff to
130 Secondary Controllers.
131 Pure Bus: A Bus topology with only I3C Devices present. No I2C Devices are permitted on a Pure Bus.
132 Push-Pull: Active Pull-Down and active Pull-Up on output driver.
133 Read-Type Transfer: An operation, typically having a single phase, in which a Device on the I3C Bus is
134 addressed and then required to either acknowledge or refuse a read transfer, based on transfer parameters sent
135 on the I3C Bus. If the Device acknowledges the transfer, then it shall immediately drive data bytes on the
136 data line (i.e., SDA) which are received by the I3C Controller and made available for the Host to read.
137 Repeated START: Two or more instances of a START in a row without an intervening STOP. A Repeated
138 START is used in circumstances where the Controller wishes to continue communicating on the I3C Bus
139 without having to first generate a STOP. In this Specification, a Repeated START is abbreviated as “Sr”. This
140 is equivalent to Repeated START in I2C [NXP01].
141 Response Descriptor: Structure used to report Command or Transfer status
142 SDR-Only: An SDR-Only Device supports only SDR Mode, i.e., does not support any HDR Mode(s).
143 Secondary Controller: Controller-capable I3C Device that controls the I3C Bus only after receiving
144 permission (i.e., after accepting Controller-role) from the Primary Controller. Control of the Bus might be
145 temporary; if so, such a Device typically passes Controller-role back to either the Primary Controller, or to
146 another Controller-capable Device.
147 Single Data Rate (SDR): Single Data Rate transfers data on only one edge of the clock.
148 Stall: The act of the I3C Controller holding the SCL LOW under specific transitory conditions.
149 START: START is the I3C Bus condition of a HIGH to LOW transition on the SDA line while the SCL line
150 remains HIGH. In this Specification, a START is abbreviated as “S”.
151 Static Address: A Device Address that is fixed and cannot be changed.
152 STOP: STOP is the I3C Bus condition of a LOW to HIGH transition on the SDA line while the SCL line
153 remains HIGH. In this Specification, a STOP is abbreviated as “P”.
154 Synchronization: Coordination of events to operate a system in unison.
155 Target: An I3C Device that can only respond to either Common or individual commands from a Controller.
156 A Target Device cannot typically generate a clock.
157 Ternary Mode: A term used as reference to I3C HDR-TSP (Ternary Symbol for Pure Bus) or HDR-TSL
158 (Ternary Symbol Legacy) Modes.
159 Version 1.1+ of the I3C Specification: See [MIPI06].
160 Word: Transmission containing 16 payload bits and two parity bits.
4 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
161 Write-Type Transfer: An operation, typically having a single phase, in which a Device on the I3C Bus is
162 addressed and then required to either acknowledge or refuse a write transfer, based on transfer parameters
163 sent on the I3C Bus. If the Device acknowledges the transfer, it shall then receive data bytes on the data line
164 (i.e., SDA) which are driven by the I3C Controller.
2.3 Abbreviations
165 e.g. For example (Latin: exempli gratia)
166 i.e. That is (Latin: id est)
167 aka. Also known as
2.4 Acronyms
168 ACK Acknowledge
169 BCR Bus Characteristics Register
170 CCC Common Command Code
171 CRC Cyclic Redundancy Check
172 CRR Controller-role Request
173 DAT Device Address Table
174 DCR Device Characteristics Register
175 DDR Double Data Rate
176 FSM Finite State Machine
177 HCI Host Controller Interface
178 HDR High Data Rate
179 HDR-BT HDR Bulk Transfer
180 HDR-DDR HDR Double Data Rate
181 HJ Hot-Join
182 IBI In-Band Interrupt
183 MDB Mandatory Data Byte
184 MHz Mega Hertz
185 MID MIPI Manufacturer ID [MIPI01]
186 NACK Not Acknowledge
187 P STOP
188 S START
189 SCL Serial Clock
190 SDA Serial Data
191 SDR Single Data Rate
192 Sr Repeated START
193 T Transition Bit
Copyright © 2022 MIPI Alliance, Inc. 5
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
194 TCRI Transfer Command/Response Interface for I3C
195 TSL Ternary Symbol Legacy
196 TSP Ternary Symbol for Pure Bus (no I2C Devices)
6 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
2.5 Color Coding
197 In some Figures in this Specification, color coding is used to indicate ownership. This includes ownership of
198 state in FSMs and other modal states. Items driven or set by the Application are indicated with yellow, and
199 items driven or set by the I3C Bus Controller are indicated with gray.
Copyright © 2022 MIPI Alliance, Inc. 7
Public Release Edition
O wb ny e
A
d , d
p p
r iv
lic a
e n
tio
/sn e t
O w n e
b yC
d , d
I3 C
o n tr
r iv e
B u
o lle
nsr /s e t
200
Figure 1 Color Coding Scheme

Specification for I3C TCRI Version 1.0
24-May-2022
3 References
201 [MIPI01] MIPI Alliance, Inc., “MIPI Alliance Manufacturer ID Page”,
202 <http://mid.mipi.org>, last accessed 12 September 2022.
203 [MIPI02] Specification for Improved Inter Integrated Circuit (I3C®), Version 1.1.1 (including all
204 released Errata), MIPI Alliance, Inc., 20 May 2021 (MIPI Board Adopted 20 May 2021).
205 [MIPI06] Version 1.1+ of the MIPI I3C Specification.
206 Note:
207 In this Specification, the term “Version 1.1+ of the I3C Specification” refers to the most
208 recently adopted MIPI I3C v1.1-based Specifications. At the time this I3C TCRI v1.0
209 Specification was adopted, this was the MIPI I3C v1.1.1 Specification (available to MIPI
210 Alliance member companies only) and the MIPI I3C Basic v1.1.1 Specification (publicly
211 available).
212 [MIPI03] I3C Application Note: General Topics (Applies to I3C v1.1+ and I3C Basic v1.1.1+),
213 App Note version 1.1, MIPI Alliance, Inc., 27 April 2022 (MIPI Board approved
214 27 July 2022).
215 [MIPI04] Discovery and Configuration (DisCoSM) Specification for I3C, Version 1.0,
216 MIPI Alliance, Inc., 23 January 2019 (MIPI Board Adopted 18 June 2019).
217 [MIPI05] MIPI Alliance Specification for I3C Host Controller Interface (I3C HCI℠), version 1.1
218 (including all released Errata), MIPI Alliance, Inc., 20 May 2021 (MIPI Board Adopted
219 20 May 2021).
220 [NXP01] UM10204, I2C Bus Specification and User Manual, Rev. 6,
221 NXP Corporation N.V., 4 April 2014.
222 [PCISIG01] PCI SIG, PCI Code and ID Assignment Specification,
223 <https://pcisig.com/specifications>, Revision 1.9, 31 May 2017.
224 [USB01] Universal Serial Bus Specification, <https://www.usb.org/document-library/usb-20-
225 specification>, Revision 2.0 (including errata and ECNs through 18 December 2018),
226 USB-IF, 27 June 27 2017.
227 [USB02] Universal Serial Bus 3.2 Specification, <https://www.usb.org/document-library/usb-32-
228 specification-released-september-22-2017-and-ecns>, Revision 1.0 (including errata and
229 ECNs through 24 July 2018), USB-IF, 22 September 2017.
230 [USB03] Universal Serial Bus I3C Device Class Specification, Revision 1.0, USB-IF,
231 7 January 2022.
8 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

| Version 1.0  |     |     |     | Specification for I3C TCRI  |     |
| ------------ | --- | --- | --- | --------------------------- | --- |
24-May-2022
4  Technical Overview
232  The MIPI I3C Specification [MIPI02] defines the behavior of the Devices on an I3C Bus. This ensures
233  Device compatibility and interoperability. However, hardware manufacturers and platform integrators have
the challenge of designing and integrating I3C Bus Controller Logic as part of a subsystem that can connect
234
235  to a Host through a system bus.
236  To promote interoperability, MIPI has defined this I3C Transfer Command/Response Interface (I3C TCRI)
to allow for easier adoption of I3C Controller capabilities into various Applications, in order to serve multiple
237
238  ecosystems. This enables the development of common Application layer implementations, while also
239  allowing for vendor-specific innovation. This Specification also defines the high-level architecture of such
240  an I3C Controller subsystem, as shown in Figure 2.
I3 C  C o n tr o lle r
noitacilppA
|     |     | I3 C  B u s  (S | D A , S C L ) |     |     |
| --- | --- | --------------- | ------------- | --- | --- |
I3 C  B u s  r
T C R I
C o n tro lle
(Q u e u e s )
L o g ic
|     |     | I3 C  S e c o n d | a r y                |                      |                   |
| --- | --- | ----------------- | -------------------- | -------------------- | ----------------- |
|     |     |                   | I3                   | C  T a rg e t(s ) 2I | C  T a rg e t(s ) |
|     |     | C o n tr o lle r  | (s )                 |                      |                   |
|     |     | I3 C  S m a       | rt S e n s oe rss ,  | N e w  I3 C          | L e g a c y       |
|     |     | H u b s , o       | r E n g in           | S e n s o rs         | S e n s o rs      |
O u t o f B a n d  In te r ru p t

241
Figure 2 I3C System Overview

242  Note:
243  Other capabilities of an instance of I3C Bus Controller Logic (i.e., capabilities not related to Transfer
244  Commands and Responses) might require additional signals or interfaces that would be presented
245  to the Application. Such aspects are not defined in this Specification. See  Section 4.1 and
246  Section 4.2 for additional context.
|     | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     | 9   |
| --- | ------------------------------------- | --- | --- | --- | --- |
|     | Public Release Edition                |     |     |     |     |

Specification for I3C TCRI Version 1.0
24-May-2022
4.1 Scope
247 This Specification defines the Application interface exposed by I3C Controller hardware, that allows for
248 implementation of I3C Specification features in a standardized, predictable, and resource-efficient manner.
249 This interface includes I3C Transfer Commands and I3C Transfer Responses, including the expected
250 hardware response and behavior for specific actions. This Specification also defines the behavior and
251 expectations required of an I3C Controller that processes single or multiple I3C Transfer Commands in an
252 ordered sequence, and generates I3C Transfer Responses for such a sequence of I3C Transfer Commands
253 that are either processed or not processed (i.e., due to interruption or transfer errors).
254 However, this Specification does not define the internal implementation of I3C Bus Controller Logic, nor
255 does it define other interface details or additional capabilities that might be required for a particular
256 Application or for optional extensions that might be chosen by the implementer. This Specification also does
257 not define Application-specific hardware requirements beyond the scope of processing I3C Transfer
258 Commands that are enqueued by the Application, and generating I3C Transfer Responses for such I3C
259 Transfer Commands. A particular Application could extend this interface per the specific use case.
260 In particular, several aspects of I3C Controller behavior relating to I3C Transfer Commands and I3C Transfer
261 Responses are not defined, such as:
262 • The specific method that a networked Application should use to establish an active session for
263 subsequent communications with the I3C Controller
264 • The specific method that an Application should use to enqueue I3C Transfer Commands to the I3C
265 Controller
266 • The channel or method that is used to send Write Data to the I3C Controller, for I3C Transfer Commands
267 that are Write-type transfers (e.g., Private Writes, Broadcast CCCs, Direct Write, or Direct SET CCCs)
268 • The specific method that an Application should use to dequeue I3C Transfer Responses
269 • The channel or method that is used to retrieve Read Data from the I3C Controller, for I3C Transfer
270 Responses that are generated for Read-type transfers (e.g., Private Reads, Direct Read, or Direct GET
271 CCCs)
272 • The channel or method that the I3C Controller uses to notify the Application of I3C In-Band Interrupts,
273 Hot-Join Requests, Controller Role Requests, or other I3C Bus events that are not listed here
274 • Means of configuring the I3C Controller or adjusting its specific parameters that govern timing, transfer
275 rates, or methods of responding to I3C Bus events that are not defined in this Specification
276 • Methods of interrupting an I3C transfer that is currently in progress (if supported for that I3C Mode)
277 • Assignment of I3C Dynamic Addresses to any I3C Target Devices on the I3C Bus
278 • How to invoke any I3C-defined error recovery methods (if such a situation becomes necessary, per the
279 I3C Specification)
280 • Additional functionality that might automatically respond to certain I3C Bus events, or particular
281 transfers on the I3C Bus based on data received, transfer status or failure
282 • Additional functionality that might perform periodic actions without receiving directly-enqueued I3C
283 Transfer Commands from the Application
284 • Multiplexing Command/Response processing among two or more Applications, or among multiple
285 Command/Response streams (i.e., separate execution contexts) offered by the same Application
286 • Any internal architectural requirements or system-level details of the Application
287 This I3C TCRI Specification does not define system-specific or platform-specific setup for the Application.
288 However, it does require certain capabilities that an Application must adhere to, in order to make use of the
289 standard Transfer Command and Transfer Response flows defined in this Specification.
290 On its own, this I3C TCRI Specification does not provide a complete implementation of all I3C Controller
291 capabilities that an Application might need. Readers are advised to read this I3C TCRI Specification in
292 conjunction with an Application-specific document, such as the MIPI I3C Host Controller Interface
293 Specification (I3C HCI, see [MIPI05]) which includes additional definitions, normative behaviors, and
294 expectations for a local Host Controller Interface.
10 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
4.2 I3C TCRI Purpose
295 The I3C Transfer Command/Response Interface is intended to standardize the Command/Response interface
296 (which handles Host-initiated transactions such as reads, writes, and CCCs) for I3C Bus Controller logic
297 within any Application, including local Host system peripherals, network bridge devices, and other
298 integrations that use I3C Device functionality that uses the I3C Controller Role.
299 This Specification is intended to be used for several purposes, including:
300 • Defining the I3C Transfer Command/Response behavior used by hardware that is compliant with the
301 MIPI I3C HCI Specification [MIPI05], when processing I3C Transfer Commands sent from a locally
302 connected Host and sending I3C Transfer Responses for such I3C Transfer Commands that are processed
303 to the Host; and
304 • Defining the I3C Transfer Command/Response behavior for an I3C network Bridge Device that
305 exchanges structured network packets through an established session with a remote entity (i.e., another
306 device on the I3C network), processes I3C Transfer Commands, and generates I3C Transfer Responses
307 for such I3C Transfer Commands that are processed to the remote entity:
308 • Suitable for MIPI A-PHY Bridging applications, where the remote entity is an A-PHY Device;
309 • Suitable for I3C Routing Devices, where the remote entity is another I3C Controller on an “upstream”
310 I3C Bus segment; or
311 • Suitable for other network applications, where the remote entity is another networked device.
312 Naturally, per the I3C Specification, this I3C Controller Interface supports Transfer Commands that can be
313 sent to either:
314 • I3C Devices (i.e., I3C Targets); and/or
315 • Legacy I2C Devices, with compatibility as described in I3C Specification.
316 This I3C TCRI Specification does not limit the classes or capabilities delivered by any Devices enumerated
317 on an I3C Bus, so long as such Devices conform to the I3C Specification.
318 Implementing the I3C TCRI Specification can reduce complexity for Application integrators developing
319 solutions that make use of existing components. For example, vendors of standardized systems that integrate
320 I3C Controller functionality can use the Transfer Command/Response Interface within their system designs
321 as part of their Application.
Copyright © 2022 MIPI Alliance, Inc. 11
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
4.3 I3C TCRI Key Features
322 The I3C TCRI Specification provides efficient means for Applications to interface to the features provided
323 by the I3C Bus, and ensures power-efficient operation of the I3C Controller. Power efficiency is particularly
324 important, as many I3C Device implementations typically target battery-powered environments.
325 In particular, the I3C TCRI supports the following I3C Specification features:
326 • Two-wire serial interface up to 12.5 MHz using Push-Pull with the following Data Rates supported:
327 • I2C compliant Data Rates:
328 • I2C Fast Mode (FM): 0 to 400 Kb/s
329 • I2C Fast Mode Plus (FM+): 0 to 1Mbps
330 • Single Data Rate (SDR): I3C enhanced version of the I2C protocol, running up to 12.5 MHz:
331 • I3C Coding SDR with Directed and Broadcast Common Command Codes (CCC)
332 • Optional High Data Rate (HDR) Modes: Additional I3C Modes, not available for the I2C protocol
333 Devices:
334 • HDR-Dual Data Rate (HDR-DDR)
335 • HDR-Ternary Symbol Legacy Mode (HDR-TSL)
336 • HDR-Ternary Symbol for Pure Bus Mode (HDR-TSP)
337 • Supported Bus Roles:
338 • I3C Primary Controller as the initial Active Controller
339 • I3C Secondary Controller that can acquire the Controller Role and become Active Controller
340 • Legacy I2C Target Device co-existence on the same Bus instance (with limitations as described in the I3C
341 Specification [MIPI02])
342 • Legacy I2C messaging
343 • Multi-Drop capability
344 • Common Command Code (CCC) Framing, namely:
345 • CCCs (Direct and Broadcast) in SDR Mode only
12 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
4.4 I3C TCRI Fundamental Principles
346 The I3C TCRI is designed to support the full functionality defined in the I3C Bus Specification [MIPI02],
347 as well as some addition features that are useful for modern platforms.
348 The fundamental principles for I3C TCRI are to:
349 • Provide a well-defined, comprehensive Application interface with full support for all transaction types in
350 supported I3C Modes
351 • Be designed to support a variety of Applications, including local Host peripherals and remote network
352 bridging solutions
353 • Provide Device operation flows, including power management aspects
354 • Use a Command/Response flow that defines various data structure formats (called Descriptors) for
355 transaction flows:
356 • This allows for simple transfers, but also enables more complex multi-part transactions
357 • It also supports selected optional HDR Modes, and provides a path for future extensibility as the I3C
358 Specification evolves
359 • Enable support for essential basic features of the I3C Specification version 1.1.1 [MIPI02]
360 Note:
361 Additional features not defined in this I3C TCRI Specification are expected to be provided by the
362 Application.
363 This Specification is written to cover the following capabilities:
364 • Transaction capability:
365 • Capability to communicate to the same Device at multiple supported clock speeds, on a per-transaction
366 basis
367 • Capability to send multiple Transfer Commands that are processed and executed as I3C transactions in
368 succession, within the same SDR Frame (i.e., without intervening STOP condition) or the same HDR
369 Frame (i.e., without HDR Exit Pattern)
370 • Capability to send Broadcast CCC and Direct CCC transfers using managed CCC transfer framing:
371 • Includes support for all variants of Direct CCC transfers, such as Direct Write/SET, Direct
372 Read/GET, and any valid combinations of the above
373 • May address one or multiple Target Devices using Dynamic Addresses; may also send to Group
374 Addresses (Direct Write/SET only)
375 • Support I3C Pure Bus and Mixed Bus configurations
Copyright © 2022 MIPI Alliance, Inc. 13
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
4.5 I3C TCRI Relationship to Other MIPI Specifications
376 This Specification describes a set of required behaviors and expectations for I3C Bus Controller Logic that
377 functions as an I3C Controller Device, as defined by v1.1+ of the MIPI I3C Specification [MIPI06].
378 Implementers are required to support the mandatory I3C Controller behaviors as well as transfers using SDR
379 Mode. Implementers may also choose to support other optional features defined in the MIPI I3C
380 Specification, such as transfers using specific HDR Modes.
381 A major purpose of this I3C TCRI Specification is to serve as the normative specification for Transfer
382 Commands and Transfer Responses for MIPI’s future I3C-related specifications, including future versions of
383 the MIPI I3C HCI Specification [MIPI05]. Sections of this I3C TCRI Specification were originally drafted
384 for, and incorporated into, earlier versions of the I3C HCI Specification.
385 • Many of the normative behaviors defined in Section 6.2, Section 6.3, and Section 6.4 were also defined
386 in version 1.1 of the I3C HCI Specification.
387 • Format 1 of the Command Descriptor and Response Descriptor (see Section 7.1) matches the formats
388 that were defined in version 1.1 of the I3C HCI Specification, and provides a comprehensive interface for
389 managing I3C transactions that use the essential (i.e., required) capabilities of the I3C Specification, as
390 well as some optional modes and capabilities.
391 • By contrast, Format 2 of the Command Descriptor and Response Descriptor (see Section 7.2) is an
392 alternative to Format 1 that was originally developed for earlier drafts of the v1.1 I3C HCI Specification.
393 Format 2 was not included in the adopted version of I3C HCI v1.1, but is now included here in this I3C
394 TCRI Specification, to allow an implementer to choose the option that is best for the particular
395 Application.
396 The I3C HCI Specification also defines additional aspects, features, and capabilities that are specific to a
397 Host system bus connection as the specific type of Application. As such, the I3C HCI Specification defines
398 additional data structures and behavioral flows for reporting I3C In-Band Interrupts (IBIs) and assigning
399 Dynamic Addresses to I3C Target Devices, along with specific operating modes that are optimized for the
400 defined Host system interface (i.e., the I3C Controller’s specific system bus and the manner in which a Host
401 interfaces with the Host Controller).
402 However, implementers of this I3C TCRI Specification are not limited by what the I3C HCI Specification
403 defines, and this I3C Transfer Command and Transfer Response interface can be used for any Application.
14 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
5 Architectural Overview (informative)
5.1 Transfer Command/Response Interface Architecture
404 This Specification defines the I3C Transfer Command/Response Interface, a set of standard conventions and
405 behaviors for an I3C Controller, including the semantics that an Application (i.e., a Host or controlling entity)
406 uses when interfacing with I3C Bus Controller Logic, in order to enqueue I3C Transfer Commands and
407 dequeue I3C Transfer Responses based on I3C Bus activity.
408 Figure 3 shows a high-level example of an I3C Controller that implements support for I3C Transfer
409 Command and I3C Transfer Response processing from its Application. This figure does not show
410 Application-specific functions that would be required for a complete implementation.
Copyright © 2022 MIPI Alliance, Inc. 15
Public Release Edition
C o m
In
c
C
R
m a n d /R e
te rfa c e to
H o s t o r
o n tro llin g
e n tity
o m m a n d
Q u e u e
e s p o n s e
Q u e u e
s p o n
I3
s
C
e P
B u
ro c e s s in g
s C o n tro lle r L
T x F IF O
R x F IF O
I3 C C o n tro
2I C C o n tro
o
l
l
g ic
2I C
I3 C
a n d
I/O
S D
S C
A
L
I3 CC So en c o
tro
n d
lle
ar ry
2I C T a rg
I3
e
C
t
T a rg e t
411
Figure 3 Example TCRI Integration with I3C Bus Controller Logic
412 In implementations like the one shown in Figure 3, the I3C Bus Controller Logic box generally contains
413 blocks for Tx FIFO, Rx FIFO, I3C Control, and I2C Control. The I3C Bus Controller Logic is responsible for
414 managing the I/O block, driving the enqueued transactions (as described by Command Descriptors),
415 managing the transfer of data to/from the FIFOs, and returning status via Response Descriptors. The
416 Application then uses these blocks in the appropriate manner, to enqueue I3C Transfer Commands with
417 optional data, and to dequeue I3C Transfer Responses with optional data. The Application also uses specific
418 methods to manage the I3C Bus Controller Logic and receive notifications of In-Band Interrupts as well as
419 other I3C Bus events and conditions.

Specification for I3C TCRI Version 1.0
24-May-2022
5.2 General Information
420 The Transfer Command Interface supports Active Controller mode, which enables a Command/Response
421 interface that the Host uses to enqueue transfers and read response status, while the I3C Bus Controller Logic
422 acts as the Active Controller of the I3C Bus.
423 Note:
424 An I3C Controller implementation may also support Standby Controller mode, if it can hold the role
425 of I3C Secondary Controller on the I3C Bus. This I3C TCRI Specification does not define any
426 requirements relating to I3C Secondary Controller capabilities or Standby Controller mode, but
427 implementers may choose to add such capabilities, depending on the use case.
428 The I3C Controller can support any number of I3C Devices and/or Legacy I2C Devices on its single I3C Bus
429 instance, as long as all such Devices have unique Dynamic Addresses (for I3C Devices) and non-conflicting
430 Static Addresses (for Legacy I2C Devices, and for I3C Devices when appropriate). The actual number of
431 Devices that can be used with an implementation might depend on several other factors, including whether
432 the supported Transfer Command format requires a DAT index, and whether the I3C Controller and its
433 Application have sufficient internal memory to support simultaneous transfers to/from multiple Devices.
5.3 Target Device Support Model
5.3.1 I3C Devices
434 An implementation that supports this Transfer Command/Response Interface as well as the data structure
435 definitions in this Specification is required to support all I3C compliant Devices, however such an
436 implementation is not required to support all I3C Bus speeds, nor all optional I3C Modes.
5.3.2 I2C Devices
437 Per the I3C Specification [MIPI02], many types of I2C Target Devices can coexist on an I3C Bus, but I2C
438 Bus Controllers cannot coexist on an I3C Bus.
439 Interrupts: Legacy I2C Devices use out-of-band mechanisms for interrupts. If the Application wishes to
440 receive such interrupts, then it must implement a method for receiving these (i.e., out-of-band signal inputs
441 or GPIO pins).
442 Read/Write: Read/writes for I2C Devices are performed in a similar manner as for I3C Devices. However the
443 array of options for scheduling traffic to an I2C Device is necessarily more limited, in terms of speed and
444 Mode.
16 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6 Theory of Operation
445 The I3C Transfer Command/Response operational flow is defined as a contract and set of expectations for
446 the Application to follow, as well as a set of behavioral requirements for a compliant I3C Bus Controller.
447 While some of these flows can be executed in parallel, they are treated separately here for purposes of
448 describing I3C Controller operation. Any necessary synchronization between the flows is called out
449 explicitly.
450 Note:
451 This section assumes that the I3C Bus Controller is operating as the Active Controller of its I3C Bus.
Copyright © 2022 MIPI Alliance, Inc. 17
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.1 Device Management and I3C Addressing
452 While this Specification does not cover the specific management of I3C Targets or Legacy I2C Targets on the
453 I3C Bus, key requirements must be observed, as detailed in subsequent sections.
6.1.1 Device Attach, Enumeration, and Initialization
454 After initialization, the I3C Bus Controller shall enumerate all its I3C Devices, and assign unique Dynamic
455 Addresses to each of them. If Legacy I2C Target Devices are also supported, then the Static Addresses of
456 such Legacy I2C Target Devices must be provided by the Application. The method of I3C Address
457 Assignment or configuration is not covered in this Specification.
6.1.2 Device Addressing
458 I3C Transfer Commands that are addressed to a specific Target Device must either include:
459 • A unique index for an entry in a special Device Address Table (i.e., DAT entry) that contains per-Target
460 configuration, including the Target Address
461 • If this is for an I3C Target, then this is typically the Target’s assigned Dynamic Address
462 • If this is for a legacy I2C Target, then this is the Target’s Static Address
463 • The Target’s I3C Address (i.e., provided directly within the Command Descriptor structure)
464 The specific method used depends on the selected Command Descriptor structure format, and the specific
465 Application might support one or both methods.
466 Note:
467 This I3C TCRI Specification does not define the structure of the I3C Controller’s DAT entry, nor does
468 it place any requirements on how many DAT entries are required to be implemented. However, if this
469 Transfer Command/Response Interface is used within another overall specification for a particular
470 Application, then that other specification could provide definitions for the structure of DAT entries,
471 and could also place requirements on the number of DAT entries.
472 I3C Transfer Commands that are addressed to a valid Group Address can also be used in a Command
473 Descriptor structure. In most cases this will be structured as a Write-type command that addresses the Group
474 Address instead of a Target Address.
475 • Since a Group Address may be assigned to multiple I3C Targets, and since all such I3C Targets will
476 participate in the ACK/NACK based on matching the Group Address in the Address Header, the I3C Bus
477 Controller Logic will regard a Transfer Command as successfully executed if all such I3C Targets
478 respond with ACK, or if at least one such I3C Target responds with an ACK.
479 • However, the I3C Bus Controller Logic has no way to determine how many of these I3C Targets
480 responded with ACK (i.e., by the Write-type command that is addressed to the Group Address) since
481 multiple ACKs are indistinguishable.
482 • If no I3C Targets provide ACK based on matching the Group Address in the Address Header, the I3C Bus
483 Controller Logic shall regard the Transfer Command as a failure, and shall return an error code 0x5
484 (NACK) in field ERR_STATUS (see Section 6.4.1.5).
485 I3C Transfer Commands that are addressed to the entire I3C Bus (e.g., Broadcast CCCs) shall indicate this,
486 in a manner specific to the Command Descriptor structure and how the Application uses it. For example:
487 • If the Application uses DAT indexes in the Command Descriptor, then the Application might define that
488 Transfer Commands for Broadcast CCCs should only include the Command Code, and the DAT entry
489 index field’s value is not needed (i.e., a value of 0x0 is acceptable).
490 • If the Application uses direct addressing, then the Application might define that Transfer Commands for
491 Broadcast CCCs should be addressed to either 7’h00 or 7’h7E (i.e., the I3C Broadcast Address) in the
492 Target Address field.
18 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6.2 Transfer Command Handling
493 An I3C Controller allows its Application to enqueue transfers via its Command Queue. While acting as the
494 Active Controller of the I3C Bus, these transfers are driven to the I3C Bus by the I3C Bus Controller Logic,
495 and the response status for each transfer shall be read by the Application from the Response Queue, to
496 determine whether the transfer succeeded or failed. This mode of operation is called Active Controller mode.
497 For each enqueued transfer, the I3C Bus Controller Logic uses the transfer parameters (such as any Command
498 Code and optional Defining Byte for a CCC) encoded in the Command Descriptor structure. These
499 parameters inform the I3C Bus Controller Logic which I3C/I2C Target Device is the recipient of the transfer,
500 or (for Broadcast CCC commands) inform the I3C Bus Controller Logic that a transfer is directed to all I3C
501 Target Devices on the I3C Bus.
502 Transfers may be either Read-Type or Write-Type:
503 • Read-Type: A Read-Type Transfer Command may address any I3C Target Device that has been assigned
504 a valid Dynamic Address.
505 • This might take the form of a Private Read (in SDR Mode), or an HDR Generic Read (in any
506 supported HDR Mode).
507 • This might take the form of a Direct Read or Direct GET CCC (in SDR Mode).
508 • Note that a Read-Type Transfer Command may not be sent to a Group Address.
509 • Write-Type: A Write-Type Transfer Command may address any I3C Target Device that has been assigned
510 a valid Dynamic Address, or a valid Group Address (if Grouped Addressing is supported).
511 • This might take the form of a Private Write (in SDR Mode), or an HDR Generic Write (in any
512 supported HDR Mode).
513 • This might take the form of a Direct Write or Direct SET CCC (in SDR Mode).
514 • This might take the form of a Broadcast CCC, which addresses all I3C Devices on the Bus.
515 • Certain Write-Type commands might be used to address I3C Target Device(s) that have not yet been
516 assigned a Dynamic Address:
517 • For example, a Write-Type Transfer Command taking the form of a Broadcast CCC (i.e., an
518 Immediate Data Transfer Command) may be used to send the SETAASA CCC, which shall assign
519 Dynamic Addresses to all I3C Target Devices that support this CCC.
520 • The Application might also define special Address Assignment Command formats, but such formats
521 are not defined in this I3C TCRI Specification.
522 Note:
523 The Transfer Command Interface shall block certain CCCs from being sent using Transfer
524 Commands from the Application, as those CCCs would automatically be sent by the I3C Bus
525 Controller Logic due to particular Transfer Command parameters.
526 For example, the ENTHDR0–ENTHDR7 CCCs are not directly accessible to the Application through
527 a Transfer Command. These CCCs are sent automatically by the I3C Bus Controller Logic, for
528 Transfer Commands that utilize an HDR Mode and also require the I3C Controller to enter that HDR
529 Mode with the appropriate CCC, to start the framing and utilize the HDR coding (per Section 6.2.5).
530 Additionally, the GETACCCR CCC is not directly accessible to the Application through a Transfer
531 Command, since this Specification does not define an interface that uses Standby Controller mode
532 and does not provide a method for passing Controller-role to a Controller-capable Device (i.e., a
533 Secondary Controller). However, this Specification can be used by Secondary Controller Devices
534 that subsequently acquire the Controller Role and become the Active Controller.
535 Additionally, the DISEC CCC might also be sent automatically by the I3C Bus Controller Logic, in
536 response to certain Interrupt Request types that are not allowed per the Application’s configuration,
537 or Application-specific per-Target configuration. However, it is allowed for this CCC to be sent via
538 Transfer Commands from the Application.
Copyright © 2022 MIPI Alliance, Inc. 19
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.2.1 Target Device Requirements
539 In general, the Application shall not initiate a transfer request to an I3C Target Device until and unless the
540 Target has been assigned a Dynamic Address. While the method of assigning a Dynamic Address is not
541 defined by this Specification, the Application that uses this I3C Transfer Command/Response Interface might
542 provide a side-band mechanism for this purpose, or it might rely on other Transfer Commands to perform
543 this process (i.e., to enqueue CCCs).
544 Once a Target Device has received its Dynamic Address, the Application may initiate transfer requests for
545 any support transfer types, including CCCs (per Section 6.3) in SDR Mode or other optional HDR Modes,
546 using a Command Descriptor and associated data. Each Command Descriptor shall indicate the Target Device
547 to which the Transfer Command is directed.
548 Note:
549 Per Section 6.1, if the I3C Controller supports a Command Descriptor format that requires indexed
550 DAT entries, then the Application must first populate a DAT entry containing the Dynamic Address
551 for a Device (or an assigned Group Address, if supported) before sending any transfer requests using
552 the index for that DAT entry.
6.2.2 Response Descriptor Generation
553 As the I3C Controller processes each Command Descriptor, it shall conditionally generate and provide
554 Response Descriptors appropriately, as indicated in field WROC for each Command Descriptor, and each
555 Response Descriptor shall provide status information for the related transfer. In general, there is a 1:1
556 mapping between Command Descriptors that the Application enqueues via the Command Queue, and
557 corresponding Response Descriptors that the I3C Controller generates and provides via the Response Queue.
558 Note:
559 The Application may also add special restrictions or change the behavior of field WROC for specific
560 operating modes, such that field WROC could have a special meaning or could also be disregarded,
561 depending on the Application requirements or the specific operating mode.
562 The Application should use different (i.e., changing) values in field TID for Command Descriptors, to uniquely
563 identify different Response Descriptors that are received and correlate them to the enqueued Command
564 Descriptors.
6.2.3 Automatic Entry and Exit for HDR Modes
565 The Speed and Mode of the transfer is set via the MODE field in the Command Descriptor structure for a
566 Transfer Command type (see Section 7). This allows the Application to choose the I3C Mode for each
567 transfer. The Command Descriptor may also define additional fields for I3C Modes that are specific to a
568 particular Command Descriptor format.
569 For all transfers in HDR Modes, the I3C Controller shall automatically enter the chosen HDR Mode, using
570 the ENTHDR0–ENTHDR7 CCCs per version 1.1.1 of the I3C Specification [MIPI02] (see Section 5.1.9.3.9)
571 upon receiving the first transfer in such an HDR Mode. The I3C Controller shall automatically exit the HDR
572 Mode at the appropriate time, using the HDR Exit Pattern. The I3C Controller shall determine when to exit
573 the HDR Mode, if any of the following conditions are true:
574 • The value in the MODE field of the next enqueued Command Descriptor to be processed has a different
575 value than the MODE field in the previous Command Descriptor; or
576 • The last Command Descriptor in the Command Queue has been processed, and either no more Command
577 Descriptors remain to be processed; or
578 • The Application has instructed the I3C Controller to halt or abort further processing; or
579 • The I3C Controller has halted operation due to an unrecoverable error.
580 The I3C Controller shall either (a) automatically exit the HDR Mode after processing a Command Descriptor
581 with a value of 1 in the TOC field, or (b) as an alternative, choose to remain in the HDR Mode for as long as
582 possible, if subsequent Command Descriptors have been enqueued that will use the same HDR Mode.
20 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
583 The I3C Controller automatically drives the HDR Restart Pattern between transactions (i.e., separate
584 Command Descriptors) in the same HDR Mode, as indicated by the TOC field containing the value 0.
585 Each transfer described by a single Transfer Command is generally a single data message between the
586 framing elements for that HDR Mode. The I3C Bus Controller Logic shall:
587 1. Start the transfer by automatically entering into that HDR Mode (i.e., after using the appropriate
588 ENTHDR0–ENTHDR7 CCC, as mentioned above), or continuing after the HDR Restart Pattern (i.e.,
589 after a previous transfer in that same HDR Mode which continued the framing, using field TOC=0).
590 2. Send the appropriate structured protocol element (e.g., a Command Word or Header Block) to drive the
591 Address, i.e., the Target Address, Group Address (if supported), or Broadcast Address; and other fields
592 specific to the particular HDR Mode, for the Command Code, Command Bytes or other transfer
593 parameters.
594 3. Send or receive the data bytes:
595 A. For a Write Transfer, the I3C Bus Controller Logic shall send the data bytes using the appropriate
596 structured protocol elements (e.g., one or more Data Words or Data Blocks), using Immediate
597 Data Bytes if indicated by the Transfer Command, or an appropriate data buffer or queue with the
598 length indicated by the Transfer Command.
599 B. For a Read Transfer, the I3C Bus Controller Logic shall receive the data bytes from the indicated
600 Target Device, and store them in the data buffer or queue.
601 C. If the Command Descriptor format supports Combo transfers, and if the Transfer Command
602 indicates that this is a Combo transfer with both phases in an HDR Mode, then the I3C Bus
603 Controller Logic shall drive an HDR Restart Pattern between the first phase and second phase. The
604 I3C Bus Controller Logic shall also re-send the appropriate structured protocol element (e.g., a
605 Command Word or Header Block) to start the second phase of the transfer, after the HDR Restart
606 Pattern, using the same Address as the first phase.
607 4. End the transfer, by either driving the HDR Restart Pattern to prepare for the next transfer in that same
608 HDR Mode (i.e., when field TOC=0); or automatically exiting that HDR Mode and driving the HDR
609 Exit Pattern (i.e., when field TOC=1, or when conditions require exiting that HDR Mode).
610 If the Command Descriptor format supports Combo transfers, and if the Transfer Command indicates that
611 this is a Combo transfer with only the second phase in an HDR Mode, then the I3C Bus Controller Logic
612 shall generate a Repeated START after the end of the first phase (i.e., in SDR Mode) and send the appropriate
613 ENTHDR0–ENTHDR7 CCC to enter the HDR Mode for the second phase, as defined above.
6.2.4 Sequences of Transfer Commands
614 The Application may enqueue individual Transfer Commands, where each Command Descriptor’s field TOC
615 has a value of 1’b1; or a consecutive sequence of Transfer Commands in a given order, comprising a
616 transaction sequence:
617 • The first and subsequent Command Descriptors (except for last in the sequence) indicate the start and
618 continuation of the sequence, with field TOC having a value of 1’b0; and
619 • The last Command Descriptor indicates the end of the sequence, with field TOC having a value of 1’b1.
620 Within such a sequence, field TOC roughly corresponds with the framing elements in the I3C Modes, as
621 defined in Section 6.2.5:
622 • In SDR Mode:
623 • If field TOC has a value of 1’b1, then the Bus transaction for that Command Descriptor shall end with a
624 STOP condition, in order to allow subsequent reception of In-Band Interrupts (IBIs).
625 • If field TOC has a value of 1’b0, then the Bus transaction shall end with a Repeated START condition,
626 and the next Command Descriptor shall be processed.
627 • In HDR Modes:
628 • If field TOC has a value of 1’b1, then the Bus transaction for that Command Descriptor shall
629 conditionally end with an HDR Exit Pattern (i.e., exiting the HDR Mode) per Section 6.2.5.
Copyright © 2022 MIPI Alliance, Inc. 21
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
630 • If field TOC has a value of 1’b0, then the Bus transaction shall end with an HDR Restart Pattern, and
631 the next Command Descriptor shall be processed with continuous framing, per Section 6.2.5.
632 Note that special additional conditions also apply for Command Descriptors that indicate CCCs, per
633 Section 6.3.
634 Whenever possible, the Application should attempt to enqueue all Command Descriptors comprising a
635 sequence of Transfer Commands as a single continuous operation or uninterrupted stream of actions, in order
636 to prevent a command sequence stall condition or timeout (as defined in Section 6.4.2). If the Command
637 Queue is unable to contain or accept all such Command Descriptors for this sequence, or if the sequence is
638 longer than the maximum size of the Command Queue, then the Application must first enqueue some
639 Command Descriptors to start processing the sequence, and then actively monitor the status of the Command
640 Queue to ensure that it is able to enqueue additional Command Descriptors when possible, while preventing
641 a command sequence stall condition or timeout.
642 The I3C Controller shall monitor the Command Queue and attempt to detect situations of possible command
643 sequence stall conditions or timeouts, reporting them as warnings or errors per Section 6.13.2. The I3C
644 Controller shall also monitor the specific execution status of the operating mode, for other mode-specific
645 conditions that might cause an interruption of transfer processing.
646 Whenever possible, the I3C Controller and its I3C Bus Controller Logic should attempt to mitigate or prevent
647 such underflow situations that might become imminent as the Command Queue drains to approach an empty
648 state, using the following methods as examples:
649 • Stalling the I3C Bus, using any methods that might be defined and enabled for the I3C Mode;
650 • Using any available I3C-Mode-specific methods to defer a transaction, or any upcoming actions that
651 might be expected in the near future; or
652 • Reducing the clock speed at which transfers are driven on the Bus.
653 In other cases, the I3C Controller and its I3C Bus Controller Logic would not be able to prevent an underflow
654 situation or other interruption of transfer processing, and would be required to cancel the sequence. In this
655 case, the I3C Bus Controller Logic would be required to end the framing using either a STOP condition or
656 HDR Exit Pattern, as appropriate for the I3C Mode. As a result, the I3C Bus Controller Logic would act as
657 though the last executed Command Descriptor had been provided the value 1’b1 in field TOC (instead of its
658 actual value of 1’b0).
659 If the I3C Controller is instructed or forced to cancel a transaction sequence for any reason (including a
660 command sequence timeout) then it shall assert an error to the Application to provide notice that the sequence
661 was terminated before receiving a Command Descriptor having field TOC=1. The specific warning and error
662 conditions relating to a command sequence stall condition or timeout shall also be reported as errors to the
663 Application.
664 Note:
665 Since some I3C content protocols might not tolerate a forced STOP condition between two transfers
666 that would otherwise need to be executed in a continuous sequence (i.e., with a Repeated START
667 or HDR Restart Pattern), the Application shall determine whether enqueueing the next Command
668 Descriptor after a cancelled sequence due to a timeout is a correct course of action, or whether the
669 command sequence must be restarted from an earlier transfer. The Application shall determine
670 whether to resume transfers after the STOP condition, or to restart from a prior Transfer Command,
671 by enqueueing new Transfer Commands appropriately for the I3C content protocol after detecting
672 the forced STOP condition. Alternatively, the Application may configure automatic halting if a
673 command sequence timeout occurs (see Section 6.4.2).
674 Refer to Section 6.2, Section 7.1.2, and Section 7.2.2 for usage of Transfer Commands.
22 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6.2.5 Speed and Mode Changes Within A Sequence
675 The Speed and Mode of the transfer is set via the MODE field in the Command Descriptor structure (see
676 Section 7.1.2 and Section 7.2.2). The I3C Controller shall interpret the value in the MODE field in
677 combination with the Transfer Command type.
678 If multiple Command Descriptors have been enqueued for processing, then the I3C Controller shall compare
679 the values of the MODE field between two Command Descriptors, to see whether the transfer Mode and Speed
680 change. If so, then the I3C Controller shall appropriately end the framing in that transaction’s mode, which
681 might end with a STOP condition or the HDR Exit Pattern, before starting the next Bus transaction according
682 to the MODE field of the next Command Descriptor.
683 The following requirements shall be observed:
684 • For a transition from SDR Mode to any HDR Mode, the I3C Controller shall check the TOC field in the
685 previous Command Descriptor, and use the appropriate method to end the framing:
686 • If field TOC was set to 0 in the previous Command Descriptor, then the I3C Controller shall drive a
687 Repeated START condition, before entering the indicated HDR Mode for the next Command
688 Descriptor.
689 • If field TOC was set to 1 in the previous Command Descriptor, then the I3C Controller shall end SDR
690 Mode framing by driving a STOP condition, and then wait for a Bus Free Condition before driving the
691 new transaction in the indicated HDR Mode for the next Command Descriptor.
692 • For a transition from any HDR Mode to any other I3C Mode (including another HDR Mode), the I3C
693 Controller shall end the HDR Mode framing using the HDR Exit Pattern, which includes the STOP
694 condition.
695 • This applies even if the previous Command Descriptor’s TOC field was set to 0. For such cases, the I3C
696 Controller must necessarily exit the current HDR Mode by driving the HDR Exit Pattern, before
697 starting the new transaction.
698 • This applies for transitions from any HDR Mode to any other HDR Mode; and for transitions from any
699 HDR Mode to SDR Mode (at any speed).
700 • For transitions between different values indicating changing data rates within SDR Mode, where the
701 previous Command Descriptor’s TOC field was set to 0:
702 • The I3C Controller’s standard behavior is to switch to the new data rate after driving the Repeated
703 START condition that separates the two transfers.
704 • A I3C Controller might also support optional alternate methods for handling such a transition. If such
705 optional alternate methods are supported, then these must be disabled by default, and explicitly enabled
706 by the Application, which will have a default configuration setting to use the standard behavior.
707 • Alternate methods might include:
708 • Terminate the transaction with an error, if the I3C Controller detects a different value of the MODE
709 field indicating a different data rate within SDR Mode, when field TOC was set to 0 in the previous
710 Command Descriptor. The error would be sent to the Host as an interrupt.
711 • End the current transaction, drive a STOP condition, and then restart SDR framing with a new
712 transaction in SDR Mode using the new data rate indicated in the next Command Descriptor. If the
713 next Command Descriptor is a CCC, then the I3C Bus Controller Logic must start the CCC framing
714 appropriately (per Section 6.3). In effect, a change in the MODE field between two different SDR
715 data rates would act as though the previous Command Descriptor’s TOC field had been set to 1.
Copyright © 2022 MIPI Alliance, Inc. 23
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
716 If field TOC is set to 1 for a Command Descriptor, then the Bus transaction shall end the framing in that I3C
717 Mode.
718 • If such a Command Descriptor indicates SDR Mode at any speed, then the I3C Controller shall end with
719 a STOP condition, in order to end the framing and also allow subsequent IBI reception.
720 • If such a Command Descriptor indicates any HDR Mode, then the I3C Controller shall generally exit the
721 current HDR Mode by driving the HDR Exit Pattern, unless an implementer supports deferred or delayed
722 exit as an optimization.
723 Such an optimization must be available to the Application, that it might be explicitly enabled or
724 disabled, where the Application will have a default configuration setting to use the standard behavior
725 (i.e., the HDR Exit Pattern is driven if field TOC is set to 1).
726 If field TOC is set to 0, and if the values of the MODE field do not change between this Command Descriptor
727 and the next Command Descriptor, then the Bus transaction shall end with either a Repeated START
728 condition (for SDR Mode) or the HDR Restart Pattern (for HDR Modes), and then the next Command
729 Descriptor shall be processed while remaining in the same speed and Mode.
730 Note:
731 For some Command Descriptors that indicate CCC transfers in SDR Mode, field TOC with a value of
732 0 might also end the CCC framing with the End of CCC Procedure for SDR Mode, depending on the
733 Command Descriptor format and the transaction type of the next Command Descriptor (see
734 Section 6.3).
735 In some special cases, the I3C Controller might be forced to end a transaction with a STOP condition (for
736 SDR Mode) or HDR Exit Pattern (for an HDR Mode), even though a Command Descriptor might have field
737 TOC set to 0. Such situations should include the case where this Command Descriptor is the last Command
738 Descriptor in the Command Queue, and where stalling the I3C Bus clock might not be permitted. For such
739 cases, in order to abide by the I3C Bus protocol, the I3C Controller would subsequently be required to drive
740 a START condition once it began the next Transfer Command (e.g., if a subsequent Command Descriptor
741 had been enqueued by the Application), if it had previously been forced to drive a STOP condition (or HDR
742 Exit Pattern) after running out of Command Descriptors to process. Depending on the I3C Mode and the type
743 of transfer indicated by the subsequent Command Descriptor, the I3C Controller might also need to
744 automatically re-enter the HDR Mode (if applicable) or restart the CCC framing in SDR Mode (if applicable),
745 in order to restore the I3C Bus to its prior state before the forced end of the prior activity.
746 Note:
747 Since an I3C content protocol might not tolerate a forced STOP condition between two transfers that
748 would otherwise need to be executed in a continuous sequence (i.e., with a Repeated START or
749 HDR Restart Pattern), the Application shall determine whether this is a correct course of action, or
750 whether the command sequence must be restarted from an earlier transfer. The Application shall
751 determine whether to resume after the STOP condition, or to restart from a prior Transfer Command,
752 by enqueueing new Transfer Commands appropriately for the I3C content protocol after detecting
753 the forced end of the prior activity.
754 If the Application signals the I3C Controller to pause or abort operations, then the I3C Controller shall attempt
755 to either complete or abort any in-progress transfers that the I3C Bus Controller Logic is currently driving.
756 When necessary, the I3C Controller shall abort such transfers at the earliest opportunity, even if the associated
757 Command Descriptor(s) have field TOC set to 0 (i.e., not the intended end of a sequence).
24 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6.2.6 Support for I3C In-Band Interrupts
758 If I3C In-Band Interrupts (IBIs) are enabled on the I3C Bus, then the I3C Controller must also provide a
759 mechanism for handling IBI Requests, Hot-Join Requests or Controller-Role Requests that might be raised
760 by I3C Target Devices on the I3C Bus. These might occur with the first Transfer Command in a sequence
761 (i.e., when the I3C Controller initiates a START condition to begin processing a Command Descriptor). If
762 this is a sequence that is enqueued after a previous sequence ends, then the last Transfer Command in the
763 previous sequence typically has field TOC set to 1, to drive the STOP condition (per Section 6.2.4).
764 The Application should configure the I3C Controller to begin such sequences (or single transfers) with
765 START followed by the I3C Broadcast Address (7’h7E) in order to provide opportunities for I3C Target
766 Devices to raise such requests (i.e., if the Bus Available Condition is not seen).
767 Note:
768 Starting I3C transfers with START followed by the I3C Broadcast Address (7’h7E) is recommended
769 by the I3C Specification (see [MIPI02] Annex A, Section A.2). If the I3C Controller does not start
770 Private Write or Private Read transfers with START followed by the I3C Broadcast Address, then any
771 I3C Targets wishing to raise an In-Band Interrupt Request would need to either: (A) wait for a START,
772 then arbitrate their Dynamic Address into the Address Header; or (B) wait for the appropriate Bus
773 Available Condition to pull SDA Low to request a START, which requires the Application to temporarily
774 pause sending Transfer Commands to create this opportunity.
775 If the Application allows for this, then the I3C Controller should ACK the IBI Request, allow the I3C Target
776 to send its IBI data payload, handle it appropriately (which might include initiating a subsequent Pending
777 Read operation to fetch more data from the I3C Target, if appropriate for the Mandatory Data Byte), and then
778 drive a Repeated START followed by the intended Transfer Command. Such IBI handling should be largely
779 transparent from the I3C Transfer Command/Response Interface, and the I3C Controller should also notify
780 the Application that the IBI Request was received and processed accordingly (i.e., via an Application-specific
781 interface).
782 Note:
783 The interface for reporting In-Band Interrupt notifications to the Application is not defined in this
784 Specification.
785 When using START followed by the Broadcast Address, if no I3C Targets take this opportunity to
786 raise an In-Band Interrupt Request, and if the Broadcast Address wins the Address Arbitration in the
787 Address Header, then the I3C Controller shall wait for the ACK of the Broadcast Address, and then
788 drive the intended Private Write or Private Read transfer after a Repeated START. However, if this
789 transfer is a CCC, then the START / 7’h7E is part of the CCC framing (i.e., entering the modality, per
790 Section 6.3).
Copyright © 2022 MIPI Alliance, Inc. 25
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.2.7 Support for I3C ‘Short’ Read-Type Transfers
791 For I3C Read-type transfers, a successful Response Descriptor (i.e., field ERR_STATUS having a value of
792 0x0) might indicate a ‘short’ Read-Type transfer, where the I3C Target Device returns fewer bytes than
793 expected, compared to the value of field DATA_LENGTH in the corresponding Transfer Command. This might
794 not necessarily be an error, as some I3C content protocols might depend on variable-length Private Read
795 transfers.
796 A Transfer Command for an I3C Read-type might indicate that a ‘short’ Read-Type transfer is permitted; or
797 it might indicate that the I3C Read-Type transfer will only be successful if the full number of requested bytes
798 is received from the I3C Target Device, and that processing should be halted if the I3C Target Device does
799 not return the requested number of bytes in the Transfer Command.
800 • If the Transfer Command indicates that a ‘short’ Read-Type transfer is allowed, and if a Read-Type
801 transfer is determined to be ‘short’:
802 Then the I3C Controller shall generate a Response Descriptor, as usual:
803 • In this case, the ‘short’ Read-Type transfer shall be handled as a Read-Type transfer of the full
804 expected length, where an I3C Target returned all requested data bytes; and shall be regarded as
805 successful unless other errors had occurred.
806 • In other words, if a ‘short’ Read-Type transfer generated no other errors, then the I3C Controller shall
807 generate a Response Descriptor with error code 0x0 (SUCCESS), and shall continue processing any
808 subsequent Transfer Commands that might be enqueued. It is the responsibility of the Application to
809 ensure that the length of the returned data is appropriate for the I3C content protocol, in the context of
810 any preceding activity (e.g., any Write-Type transfers or CCCs sent before such a Read-Type transfer)
811 before determining whether a ‘short’ Read-Type transfer is actually a successful result.
812 • If the Transfer Command indicates that a ‘short’ Read-Type transfer is not permitted, and if a Read-
813 Type transfer is determined to be ‘short’:
814 Then the I3C Controller shall treat this as an error:
815 • In this case, the I3C Controller shall end the framing after the Read-Type transfer (i.e., regardless of
816 the value of field TOC in the Transfer Command), and shall generate a Response Descriptor with error
817 code 0x7 (I3C_SHORT_READ_ERR) in field ERR_STATUS (per Section 6.4.1.7). The I3C Controller shall
818 then halt operations, and shall assert an error to the Application.
819 Specific Transfer Command types that allow a ‘short’ Read-Type transfer to be treated as an error
820 include the following:
821 • For Format 1 (Legacy Format, Indexed with DAT): Regular Data Transfer Command (see
822 Section 7.1.2.2)
823 • For Format 2 (Legacy Format, Direct Addressed): Regular Data Transfer Command (see
824 Section 7.2.2.2)
825 Note:
826 If the Transfer Command type does not specify otherwise, or if a Transfer Command type does not
827 define a field that provides control over whether a ‘short’ Read-Type transfer might be permitted or
828 not permitted, then the I3C Controller shall always treat a ‘short’ Read-Type transfer as though it were
829 permitted (i.e., successful unless other errors occur).
830 Since the I3C Controller always generates Response Descriptors for Read-Type transfers that are processed,
831 field DATA_LENGTH for the Response Descriptor of a ‘short’ Read-Type transfer shall contain the actual
832 number of data bytes returned from the I3C Target Device.
26 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

| Version 1.0  |     |     |     |     |     |     |     | Specification for I3C TCRI  |     |     |
| ------------ | --- | --- | --- | --- | --- | --- | --- | --------------------------- | --- | --- |
24-May-2022
6.3  Managed CCC Transfer Framing Model
833  Per Figure 4 (reproducing Figure 41 from the I3C v1.1.1 Specification [MIPI02]), the framing model for
Direct CCC commands makes it possible to address more than one Target with a sequence of commands, as
834
835  described in the I3C Specification at Section 5.1.9.2.2 [MIPI02].
|     |     |     |     |     | D e s c rib | e s  F irs t T a rg e t (o | r G ro u p ) |     |                         |           |
| --- | --- | --- | --- | --- | ----------- | -------------------------- | ------------ | --- | ----------------------- | --------- |
|     |     |     |     |     |             |                            |              |     | E n d  o f th is  D ire | c t C C C |
P
|     | S      |            |         |      |                | S u b -             |                |     |     |     |
| --- | ------ | ---------- | ------- | ---- | -------------- | ------------------- | -------------- | --- | --- | --- |
|     |        | D ire c t  | D e fin | in g | T a rg e t A d | d r C o m m a n d   |                |     | P   |     |
|     | 7 ’h 7 | E          | B y te  |      |                |                     | D a ta         |     |     |     |
|     |        | C C C      |         | S r  | o r            | B y te              | (P e r C C C ) |     |     |     |
/ W  / A C K (P e r C C C ) G ro u p  A d d r 7 ’h 7 EC T a rg e t A d d r
|     |     | / T |     |     |                | (P e r C C C ) | / T | S r      | S r            |     |
| --- | --- | --- | --- | --- | -------------- | -------------- | --- | -------- | -------------- | --- |
|     |     |     | / T |     | / R n W  / A C | K              |     | / W  / A | K / R n W  / A | C K |
| S   | r   |     |     |     |                | / T            |     |          |                |     |
N e x t C C C
|      |     |     |     |     | R e p e a t to  a | d d re s s  a d d itio n a | l T a rg e ts  (o r  |     |     |     |
| ---- | --- | --- | --- | --- | ----------------- | -------------------------- | -------------------- | --- | --- | --- |
|      |     |     |     |     | G ro u            | p s ) w ith  th is  D ire  | c t C C C            |     |     |     |
| 836  |     |     |     |     |                   |                            |                      |     |     |     |
Figure 4 Direct CCC Framing Model
837  Per Figure 5 (reproducing Figure 40 from the I3C v1.1.1 Specification [MIPI02]), Broadcast CCCs also
838  have a similar framing model.
|     |     |     |     |     |     |     | E n d  o f th | is  B r o a d c | a s t C C C |     |
| --- | --- | --- | --- | --- | --- | --- | ------------- | --------------- | ----------- | --- |
P
|     |     | S        |     |              | D e fin  | in g          |                   |       |     |     |
| --- | --- | -------- | --- | ------------ | -------- | ------------- | ----------------- | ----- | --- | --- |
|     |     |          |     | B ro a d c a | s t      | Dp a ta  a    |                   |       |     |     |
|     |     | 7 ’h     | 7 E | C C C        | B y      | te   (O tio n | l)  T a r g e t A | d d r |     |     |
|     |     |          |     |              | (O p tio | n a l)        |                   |       |     |     |
|     |     | / W  / A | C K |              |          |               | / R n W  / A      | C K   |     |     |
|     |     |          |     | / T          |          | / T           | S r               |       |     |     |
|     |     | S r      |     |              | / T      |               | 7 ’h              | 7 E   |     |     |
N e x t C C C
|      |     |     |     |     |     |     | / W  / A | C K |     |     |
| ---- | --- | --- | --- | --- | --- | --- | -------- | --- | --- | --- |
| 839  |     |     |     |     |     |     |          |     |     |     |
Figure 5 Broadcast CCC Framing Model
Both of these models are allowed within SDR Mode framing. As a result, a single large transfer may contain
840
841  any combination of Direct CCC segments, Broadcast CCC messages, and Private Read/Write transfers.
842  The I3C Controller shall support a managed CCC transfer framing model, using Command Descriptors to
send one or more CCCs using standard CCC framing in SDR Mode, and optionally in supported HDR Modes.
843
844  Each Command Descriptor that indicates a CCC transfer (i.e., a Transfer Command that is either a Direct
845  CCC segment or a Broadcast CCC message) shall be sent according to the defined CCC framing in the
846  indicated I3C Mode.
847  Note:
848  Support for Managed CCC framing in optional HDR Modes shall depend on the Command Descriptor
849  format, and the Application may choose to support HDR Modes. See Section 6.3.5 for more details.
|     |     |     |     | Copyright © 2022 MIPI Alliance, Inc.  |                         |     |     |     |     | 27  |
| --- | --- | --- | --- | ------------------------------------- | ----------------------- | --- | --- | --- | --- | --- |
|     |     |     |     |                                       | Public Release Edition  |     |     |     |     |     |

Specification for I3C TCRI Version 1.0
24-May-2022
850 For example, if the Application enqueues a single Command Descriptor with field TOC set to 1’b1, then the
851 I3C Bus Controller Logic shall automatically drive any necessary framing elements that are appropriate for
852 the CCC transfer:
853 • For a Direct CCC: The I3C Bus Controller Logic shall start the framing automatically, by driving a
854 START or Repeated START condition. The I3C Bus Controller Logic shall then send the Broadcast
855 Address (i.e., 7’h7E), the Command Code for the Direct CCC, the optional Defining Byte (if indicated),
856 and a Repeated START, before sending the Dynamic Address of the indicated Device from the Command
857 Descriptor.
858 • If the indicated Device ACKs its Dynamic Address along with the RnW bit:
859 • For Direct Write or Direct SET CCCs: The I3C Bus Controller Logic shall send the data for this
860 Direct CCC segment. The data might be sent as Immediate Data Bytes contained within the
861 Command Descriptor, or it might be sent from the Tx Data Buffer.
862 • For Direct Read or Direct GET CCCs: The I3C Bus Controller Logic shall allow the indicated
863 Device to return data, which shall be stored into the Rx Data Buffer.
864 • If the indicated Device NACKs its Dynamic Address along with the RnW bit:
865 • The I3C Controller shall attempt to retry the Direct CCC at least once following the first NACK, per
866 the following conditions:
867 • If the indicated Device’s DAT entry indicates no retries for NACKed Transfer Commands, then
868 the I3C Controller shall always attempt one retry for a NACKed Direct CCC, per the I3C
869 Specification’s mandatory single-retry model (see the I3C Specification at Section 5.1.9.2.3
870 [MIPI02]).
871 • However, if the indicated Device’s DAT entry indicates any additional retries, then the I3C
872 Controller shall retry according to that field’s setting.
873 • If the indicated Device NACKs its Dynamic Address repeatedly, beyond the retry count determined
874 by the above conditions, then this shall be reported as an error per Section 6.3.3.
875 • For a Broadcast CCC: The I3C Bus Controller Logic shall start the framing automatically, by driving a
876 START or Repeated START condition. The I3C Bus Controller Logic shall then send the Broadcast
877 Address, the Command Code for the Broadcast CCC, the optional Defining Byte (if indicated), and the
878 data message indicated by (or contained within) the Command Descriptor.
879 Since this transfer uses a single Command Descriptor, the I3C Bus Controller Logic shall drive a STOP
880 condition at the end of the transfer.
881 The Application may enqueue such a Command Descriptor indicating a CCC with any Command Code value,
882 for any CCC (Broadcast or Direct) that is not blocked by the I3C Controller, according to the list of blocked
883 CCCs (per Section 6.2).
884 Similarly, the Application can control whether a Transfer Command containing a CCC will use a Defining
885 Byte or not. The specific method shall vary, depending on the specific Transfer Command type and the field
886 values in the Transfer Command (see Section 7).
887 The I3C Controller shall neither expect nor require the Application to enqueue any preceding Command
888 Descriptors that might attempt to manually drive the CCC framing (i.e., by sending the Broadcast Address or
889 other bytes) and do not also contain all necessary values for the Direct CCC segment (i.e., the indicated
890 Device and the data) or the Broadcast CCC message (i.e., the data to send to the I3C Bus). The Application
891 should not attempt to enqueue any Command Descriptors that would attempt to manually drive such CCC
892 framing (or second-guess the I3C Bus Controller Logic by directing transfers to the I3C Broadcast Address
893 for each component of CCC framing).
28 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6.3.1 Direct CCC Framing with Multiple Segments in a Transfer
894 To perform such a transfer comprising multiple Direct CCC segments using the same CCC and optional
895 Defining Byte, the Application shall enqueue multiple consecutive Command Descriptor entries in the
896 Command Queue. For multiple segments of the same Direct CCC, the Command Descriptors shall have the
897 following properties:
898 • The Command Attribute (CMD_ATTR) field shall be set to an appropriate value for a Transfer Command,
899 specific to the Transfer Command type (see Section 7.1.2 and Section 7.2.2)
900 • The Terminate on Completion (TOC) field shall be set to 1’b0 for all such Command Descriptors, except
901 the last
902 • The TOC field shall be set to 1’b1, only for the last Command Descriptor
903 • Specific other fields shall indicate a CCC-type transfer (i.e., segment), depending upon the Transfer
904 Command type:
905 • For an Immediate Data Transfer Command, see Section 7.1.2.1.1 and Section 7.2.2.1.1
906 • For a Regular Data Transfer Command, see Section 7.1.2.2.1 and Section 7.2.2.2.1
907 • Note that Direct CCCs are in the range 0x80–0xFF (see the I3C Specification [MIPI02] at
908 Section 5.1.9.3)
909 • In addition, other fields shall contain the same Command Code and optional Defining Byte values in all
910 such Command Descriptors, per the Transfer Command type.
911 CCCs with Defining Bytes may be used in sequences of CCCs as part of Direct CCC command framing. The
912 I3C Controller shall drive CCC framing appropriately, and shall determine when to restart the CCC framing
913 upon detecting any transitions between different Defining Byte values within the same CCC, or transitions
914 between using a Defining Byte or not using a Defining Byte (in either direction).
915 The first Command Descriptor structure for such a transfer shall include all values needed to send the first
916 Direct CCC segment, i.e., to send the desired Command with optional Defining Byte to the first Target
917 Device. The subsequent Command Descriptor structures within the same transfer shall each include all values
918 needed to send a subsequent Direct CCC segment, and each shall have all field values matching the first
919 Command Descriptor structure, except for the following:
920 • If the Command Descriptor format uses indexes to a DAT, then field DEV_INDEX shall provide the index
921 to a valid DAT entry, containing the specific Target’s Dynamic Address (or a valid Group Address, if
922 appropriate) that is addressed by a subsequent Direct CCC segment.
923 • If the Command Descriptor format directly uses the Target addresses, then field DEV_ADDRESS shall
924 provide the specific Target’s Dynamic Address (or a valid Group Address, if appropriate) that is
925 addressed by a subsequent Direct CCC segment.
926 • Specific fields shall indicate that the Command Descriptor is a Direct CCC segment, as shown above
927 • Fields shall indicate the data to read from the addressed Target Address, for a Direct Read or Direct GET
928 CCC segment; or the data to write to the addressed Target Address (or Group Address), for a Direct Write
929 or Direct SET CCC segment:
930 • For Direct Write or Direct SET CCC segments, the Command Descriptor might contain Immediate
931 Data Bytes, which might also require a different value in field CMD_ATTR or other fields, per the
932 Transfer Command type; the I3C Controller shall otherwise treat such Command Descriptors
933 equivalently (i.e., Immediate versus Regular) in order to verify the intent of writing data and
934 continuing the CCC framing;
935 • Field TOC shall be set to 1’b1 only in the last Command Descriptor; otherwise, field TOC shall be set to
936 1’b0 for other subsequent Command Descriptors (i.e., not the last in the sequence, per Section 6.2.4).
937 The I3C Controller shall process such a sequence of multiple consecutive Command Descriptor entries
938 having these properties, and shall drive the appropriate actions on the I3C Bus. Since all such Command
939 Descriptors have the same CCC and optional Defining Byte values, the I3C Bus Controller Logic shall only
940 start the framing once, by sending the Broadcast Address (i.e., 7’h7E), the CCC, the optional Defining Byte
941 (if indicated), and a Repeated START, before sending the Dynamic Address of the first indicated Device from
942 the first Command Descriptor. The I3C Bus Controller Logic shall also not be required to re-send these
Copyright © 2022 MIPI Alliance, Inc. 29
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
943 elements (i.e., restarting the CCC framing) between Direct CCC segments, since the CCC and optional
944 Defining Byte are the same for all such Command Descriptors.
945 However, in situations where the I3C Controller detects that the CCC or optional Defining Byte values do
946 change from one Command Descriptor to the next, the I3C Bus Controller Logic shall restart the CCC
947 framing appropriately, by sending the Broadcast Address, the new CCC, the new Defining Byte and then
948 another Repeated START, per Direct CCC framing in SDR Mode.
949 Note:
950 The managed CCC transfer framing model of one Command Descriptor per Direct CCC segment is
951 structured such that, were each single Command Descriptor in such a sequence to be enqueued
952 separately by the Application (i.e., not consecutively as part of a sequence) with field TOC set to 1 for
953 each Command Descriptor, the I3C Bus Controller Logic would still have all values needed to send
954 each Direct CCC segment on its own (i.e., without any other Command Descriptors to indicate any
955 CCC framing elements in SDR Mode) as a separate transaction on the I3C Bus. Note that such a
956 change would mean that the I3C Bus Controller Logic must necessarily start the Direct CCC framing
957 (i.e., by starting the SDR frame and sending the Broadcast Address, CCC and optional Defining Byte)
958 before each Direct CCC segment, and it must also drive a STOP condition at the end of each Direct
959 CCC segment. Determining whether this would be a valid and correct use of such CCCs in a
960 sequence for any particular I3C content protocol is beyond the scope of this I3C TCRI Specification.
6.3.1.1 Operating Modes, Flow, and Requirements
961 For Direct Write or Direct SET CCC segments with short payloads: The Application may optionally use
962 Immediate Data Transfer Commands under certain circumstances, according to the Transfer Command
963 definition and the length of the Direct SET CCC payload (e.g., see Section 7.1.2.1 and Section 7.2.2.1).
964 For Direct Write or Direct SET CCC segments with longer payloads: The Application shall use Regular
965 Data Transfer Commands (e.g., see Section 7.1.2.2 and Section 7.2.2.2).
966 For all Direct Read or Direct GET CCC segments: The Application shall use Regular Data Transfer
967 Commands (e.g., see Section 7.1.2.2 and Section 7.2.2.2).
968 All such Command Descriptors should be enqueued to the Command Queue in sequential order. The
969 Application should generally prepare and enqueue these Command Descriptors in one operation (i.e., without
970 allowing the Command Queue to become empty in the middle of processing).
30 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

| Version 1.0  |     |     |     |     |     | Specification for I3C TCRI  |     |     |
| ------------ | --- | --- | --- | --- | --- | --------------------------- | --- | --- |
24-May-2022
971  Processing Flow and Requirements
972  Figure 6 shows a representation of the high-level logical flow that the I3C Controller shall use when
973  processing multiple consecutive Command Descriptors in such a multi-segment Direct CCC transfer, using
Direct CCC framing in SDR Mode. This flow does not depend on any specific Transfer Command type (per
974
975  Section 6.2) and shows how the I3C Bus Controller Logic determines when it must restart the CCC framing.
976  This flow allows the I3C Bus Controller Logic to optimize for efficient I3C Bus transfers by not re-sending
977  CCCs or Defining Bytes unless necessary.
|     |     |     |     |     |     | B     | e g in  C C C  fra m in g  a t firs | t   |
| --- | --- | --- | --- | --- | --- | ----- | ----------------------------------- | --- |
|     |     |     |     |     |     | C o m | m a n d  D e s c rip to r fo r C    | C C |
edoM C3I emas eht ni srotpircseD dnammoC llA C o m m a n d  D e s c r ip to r  # 1 R e s p o n s e  D e s c r ip to r  # 1
|      | (A d d | re s s , C C C , D   | e fB y te * , D a ta ) v a    | lid , T O C = 0 |                  | (S ta tu s , D | a ta L e n ) v a lid               |          |
| ---- | ------ | -------------------- | ----------------------------- | --------------- | ---------------- | -------------- | ---------------------------------- | -------- |
|      |        | C o m m              | a n d  D e s c r ip to r  # 2 |                 |                  | R e s p o n s  | e  D e s c r ip to r # 2           |          |
|      | (A d d | re s s ,  C C C ,  D | e fB y te * , D a ta ) v a    | lid , T O C = 0 |                  | (S ta tu s , D | a ta L e n ) v a lid               |          |
|      |        |                      |                               |                 |                  | O n            | ly  s e n d  R e p e a te d  S T   | A R T ,  |
|      |        | C o m p              | a re  C C C  w ith            | C o m p a re  D | e fB y te  w     | ith            |                                    |          |
|      |        |                      |                               |                 |                  | 7              | 'h 7 E , n e w  C C C  a n d  n    | e w      |
|      |        | p re v io            | u s  C o m m a n d            | p re v io u s   |  C o m m a n     | d              |                                    |          |
|      |        |                      |                               |                 |                  |                | D e fB y te *  (if u s e d ) w h   | e n      |
|      |        | D                    | e s c rip to r                | D e s c rip     | to r (if u s e d | )              |                                    |          |
|      |        |                      |                               |                 |                  | n e            | c e s s a ry  fo r C C C  fra m    | in g     |
|      |        | C o m m              | a n d  D e s c r ip to r  # 3 |                 |                  | R e s p o n s  | e  D e s c r ip to r  # 3          |          |
|      | (A d d | re s s ,  C C C ,  D | e fB y te * , D a ta ) v a    | lid , T O C = 1 |                  | (S ta tu s , D | a ta L e n ) v a lid               |          |
|      |        |                      |                               |                 |                  | E              | n d  C C C  fra m in g  a fte r la | s t      |
|      |        |                      |                               |                 |                  | C o m          | m a n d  D e s c rip to r (T O     | C = 1 )  |
| 978  |        |                      |                               |                 |                  |                |                                    |          |
Figure 6 Support for Direct CCC Commands Framing Model
979  In the high-level logical flow illustrated above, the flow shows how a transfer comprising three consecutive
980  Command Descriptors for Direct CCC GET or SET segments (either with or without Defining Bytes) shall
be processed in an optimal manner, as the I3C Controller compares the relevant field values for two adjacent
981
982  Command Descriptors.
983  While processing Direct CCC framing, the following conditions and requirements are defined:
984  • The I3C Controller shall drive a START or Repeated START condition for the first such Command
985  Descriptor, followed by the Broadcast Address (i.e., 7’h7E), then the Command Code, followed by the
optional Defining Byte (if indicated in the Command Descriptor).
986
987  • If a Command Descriptor’s field TOC is 0, then the I3C Controller shall attempt to stay in the CCC
988  framing for SDR Mode after that segment. However, if a Command Descriptor’s field TOC is 1, then the
I3C Controller may exit the CCC framing for SDR Mode, by driving a STOP condition after that
989
990  segment.
991  • The I3C Controller shall compare the fields containing the CCC and optional Defining Byte values, and
shall only restart the CCC framing (i.e., drive a Repeated START, the Broadcast Address, the CCC and
992
993  optional Defining Byte) if required for the next CCC segment, if any of the following cases are detected:
994  • If the previous Command Descriptor indicated no Defining Byte, but the next Command Descriptor
995  did indicate a Defining Byte was present;
• If the previous Command Descriptor indicated that a Defining Byte was present, but the next
996
997  Command Descriptor indicated no Defining Byte;
998  • If the previous Command Descriptor and next Command Descriptor had the same CCC value, and both
did indicate different Defining Byte values; or
999
|     |     |     | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     |     | 31  |
| --- | --- | --- | ------------------------------------- | --- | --- | --- | --- | --- |
|     |     |     | Public Release Edition                |     |     |     |     |     |

|     | Specification for I3C TCRI  |     |     |     |     |     | Version 1.0  |     |
| --- | --------------------------- | --- | --- | --- | --- | --- | ------------ | --- |
|     |                             |     |     |     |     |     | 24-May-2022  |     |
• If the previous Command Descriptor and next Command Descriptor had different CCC values.
1000
• If none of the above cases were detected, then the I3C Controller shall not restart the CCC framing, and
1001
1002  shall only drive a Repeated START, followed by the Dynamic Address of the Target Address (or Group
1003  Address, for Direct SET CCCs that might support such addressing) in order to start the next segment.
1004  These conditions and requirements for restarting the Direct CCC framing based on Command Descriptor
fields  are  aligned  with  the  End  of  CCC  Command  method  specified  in  the  I3C  Specification  at
1005
1006  Section 5.1.9.2.1 [MIPI02].
|     | 6.3.1.2  | Example Flows  |     |     |     |     |     |     |
| --- | -------- | -------------- | --- | --- | --- | --- | --- | --- |
1007  Figure 7 shows an example of three consecutive Command Descriptors for Direct CCC segments, each
having the same CCC value and different Defining Byte values. In this example, the I3C Controller detects
1008
1009  the changing Defining Byte fields in the second and third Command Descriptors, so its I3C Bus Controller
1010  Logic must restart the CCC framing in order to send the and new Defining Byte value before each such
1011  segment, even though the CCC field does not change. Since restarting the CCC framing means that the new
1012  Defining Byte value is written to the I3C Bus (along with the CCC value), it remains in force for the next
Direct CCC segment addressing a Target Device.
1013
|     |       | Direct  Defining  | Target     |      | Direct  | Defining   | Target  |     |
| --- | ----- | ----------------- | ---------- | ---- | ------- | ---------- | ------- | --- |
|     | 7’h7E |                   |            | Data | 7’h7E   |            | Data    |     |
|     | S     | CCC Byte #1       | Sr Address | Sr   | CCC     | Byte #2 Sr | Address |     |
/ W / ACK / T / T / RnW / ACK / T / W / ACK / T / T / RnW / ACK / T
|     |                                               | Command Descriptor #1 |              |                   | Command Descriptor #2                         |      |     |     |
| --- | --------------------------------------------- | --------------------- | ------------ | ----------------- | --------------------------------------------- | ---- | --- | --- |
|     | (Address, CCC, DefByte #1, Data) valid, TOC=0 |                       |              |                   | (Address, CCC, DefByte #2, Data) valid, TOC=0 |      |     |     |
|     |                                               |                       |              | Direct  Defining  | Target                                        |      |     |     |
|     |                                               |                       | 7’h7E        |                   | Sr                                            | Data |     |     |
|     |                                               |                       | Sr / W / ACK | CCC Byte #3       | Address                                       | / T  | P   |     |
|     |                                               |                       |              | / T / T           | / RnW / ACK                                   |      |     |     |
Legend Implicitly driven, required for CCC framing
|     | Based on Command Descriptor parameters |     |     | Command Descriptor #3 |     |     |     |     |
| --- | -------------------------------------- | --- | --- | --------------------- | --- | --- | --- | --- |
(Address, CCC, DefByte #3, Data) valid, TOC=1
| 1014  |     | Continue or end, based on TOC field |     |     |     |     |     |     |
| ----- | --- | ----------------------------------- | --- | --- | --- | --- | --- | --- |
Figure 7 Direct CCC Commands Framing Model: Example 1
|     | 32  |     | Copyright © 2022 MIPI Alliance, Inc.  |                         |     |     |     |     |
| --- | --- | --- | ------------------------------------- | ----------------------- | --- | --- | --- | --- |
|     |     |     |                                       | Public Release Edition  |     |     |     |     |

|     | Version 1.0  |     |     |     |     |     |     |     |     | Specification for I3C TCRI  |     |     |
| --- | ------------ | --- | --- | --- | --- | --- | --- | --- | --- | --------------------------- | --- | --- |
24-May-2022
Figure 8 shows an example of three consecutive Command Descriptors for Direct CCC segments, each
1015
1016  having different CCC values. In this example, the I3C Controller detects the changing CCC fields in the
1017  second and third Command Descriptors, so its I3C Bus Controller Logic must restart the CCC framing in
1018  order to send the CCC value and new Defining Byte value before each such segment. For both such
1019  transitions, restarting the CCC framing means that the new CCC value and its Defining Byte value are written
to the I3C Bus, such that they remain in force for the next Direct CCC segment addressing a Target Device.
1020
|     |     |          | D irec t  | D efin in g   | T a rg | e t   |     | D irec t  | D efin in g   | T a rg e t  |       |     |
| --- | --- | -------- | --------- | ------------- | ------ | ----- | --- | --------- | ------------- | ----------- | ----- | --- |
|     |     | 7 ’h 7 E |           |               |        | D ata | 7   | ’h 7 E    |               |             | D ata |     |
S C C C  # 1 B yte  # 1 S r A d d re ss S r C C C  # 2 B yte  # 2 S r A d d re ss
/ W  / A C K / T / T / R nW  / A C K / T / W  / A C K / T / T / R nW  / A C K / T
|     |     |               | C om m a n d D                         | e scriptor #1           |              |              |                   | C om m a n d D                 | e scriptor #2           |         |     |     |
| --- | --- | ------------- | -------------------------------------- | ----------------------- | ------------ | ------------ | ----------------- | ------------------------------ | ----------------------- | ------- | --- | --- |
|     |     | (A d dre ss,  | C C C  # 1 ,  D efB y                  | te #1 , D ata) valid, T | O C = 0      |              | (A d              | dre ss,  C C C  # 2 ,  D efB y | te #2 , D ata) valid, T | O C = 0 |     |     |
|     |     |               |                                        |                         |              | D irec t     | D efin in         | g   T a rg e t                 |                         |         |     |     |
|     |     |               |                                        |                         | 7 ’h 7       | E            |                   |                                | D ata                   |         |     |     |
|     |     |               |                                        |                         | S r / W  / A | C K C C C  # | 3 B yte  #        | 3 S r A d d re ss              | / T                     | P       |     |     |
|     |     |               |                                        |                         |              | / T          | / T               | / R nW  / A C K                |                         |         |     |     |
|     |     | L eg end Im   | plicitly driven, required for CCC fram | ing                     |              |              |                   |                                |                         |         |     |     |
|     |     | Based on Com  | m and Descriptor param                 | eters                   |              | CC om m a n  | d D e scriptor #3 |                                |                         |         |     |     |
1021  Continue or end, based on TO C field (A d dre ss, C C  #3 ,  D efB y te #3 , D ata) valid, T O C = 1
Figure 8 Direct CCC Commands Framing Model: Example 2
1022  Figure 9 shows an example of three consecutive Command Descriptors for Direct CCC segments, where the
1023  first has no Defining Byte value, while the second and third each have different Defining Byte values for the
1024  same CCC. In this example, even though the I3C Controller detects that the CCC fields are unchanged for
1025  all three Command Descriptors, the transition from a CCC without a Defining Byte value to a CCC with a
particular Defining Byte value (i.e., between the first and second Command Descriptors) requires the I3C
1026
1027  Bus Controller Logic to restart the CCC framing, in order to re-send the CCC value with the Defining Byte
1028  value before the second Direct CCC segment. Similarly, the transition between different Defining Byte values
1029  (i.e., between the second and third Command Descriptors) requires the I3C Bus Controller Logic to restart
1030  the CCC framing again, in order to send the CCC value and the new Defining Byte value before the third
Direct CCC segment. For both such transitions, restarting the CCC framing means writing the CCC value
1031
1032  and the new Defining Byte value to the I3C Bus, such that they remain in force for the next Direct CCC
1033  segment addressing a Target Device.
7’h7E Direct  Target  Data 7’h7E Direct  Defining  Target  Data
|     |     | S   | CCC #1 | Sr Address |     | ... | Sr  | CCC | Byte #2 | Sr Address |     |     |
| --- | --- | --- | ------ | ---------- | --- | --- | --- | --- | ------- | ---------- | --- | --- |
/ W / ACK / T / RnW / ACK / T / W / ACK / T / T / RnW / ACK / T
|     |     |                                               | Command Descriptor #1 |     |           |         |                                               | Command Descriptor #2 |      |     |     |     |
| --- | --- | --------------------------------------------- | --------------------- | --- | --------- | ------- | --------------------------------------------- | --------------------- | ---- | --- | --- | --- |
|     |     | (Address, CCC, No DefByte, Data) valid, TOC=0 |                       |     |           |         | (Address, CCC, DefByte #2, Data) valid, TOC=0 |                       |      |     |     |     |
|     |     |                                               |                       |     | 7’h7E     | Direct  | Defining                                      | Target                | Data |     |     |     |
|     |     |                                               |                       |     | Sr        | CCC     | Byte #3                                       | Sr Address            |      | P   |     |     |
|     |     |                                               |                       |     | / W / ACK |         |                                               |                       | / T  |     |     |     |
|     |     |                                               |                       |     |           | / T     | / T                                           | / RnW / ACK           |      |     |     |     |
Legend Implicitly driven, required for CCC framing
|     |     | Based on Command Descriptor parameters |     |     |     | Command Descriptor #3 |     |     |     |     |     |     |
| --- | --- | -------------------------------------- | --- | --- | --- | --------------------- | --- | --- | --- | --- | --- | --- |
(Address, CCC, DefByte #3, Data) valid, TOC=1
| 1034  |     |     | Continue or end, based on TOC field |     |     |     |     |     |     |     |     |     |
| ----- | --- | --- | ----------------------------------- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
Figure 9 Direct CCC Commands Framing Model: Example 3
|     |     |     |     |     | Copyright © 2022 MIPI Alliance, Inc.  |                         |     |     |     |     |     | 33  |
| --- | --- | --- | --- | --- | ------------------------------------- | ----------------------- | --- | --- | --- | --- | --- | --- |
|     |     |     |     |     |                                       | Public Release Edition  |     |     |     |     |     |     |

| Specification for I3C TCRI  |     |     |     |     |     |     |     |     | Version 1.0  |
| --------------------------- | --- | --- | --- | --- | --- | --- | --- | --- | ------------ |
|                             |     |     |     |     |     |     |     |     | 24-May-2022  |
1035  Note:
1036  The I3C Controller would also detect the reverse of the situation shown in the previous example,
1037  where one Command Descriptor indicated a CCC with a particular Defining Byte value, and the next
1038  Command Descriptor indicated the same CCC without a Defining Byte. Such a situation would
1039  require the I3C Bus Controller Logic to restart the CCC framing, in order to re-send the CCC value
1040  (without a Defining Byte) before sending the Direct CCC segment associated with the next Command
1041  Descriptor.
1042  Figure 10 shows an example of three consecutive Command Descriptors for Direct CCC segments, each
having the same CCC and Defining Byte values. In this example, the I3C Controller drives the CCC and
1043
1044  Defining Byte value, as part of starting the CCC framing on behalf of the first Command Descriptor. It then
1045  subsequently detects no changes to the CCC fields or the Defining Byte fields, for either the second or third
1046  Command Descriptors. Since fields do not change, the I3C Bus Controller Logic is not required to restart the
1047  CCC framing for each Direct CCC segment. The CCC and Defining Byte that were sent at the start of CCC
framing (i.e., on behalf of the first Command Descriptor) remain in force, as all such Target Devices that
1048
1049  support CCCs shall have been required to track the CCC and Defining Byte value, per CCC framing in SDR
1050  Mode.
|     |          | D ire c | t  D e fin in g   | T a rg e | t   | T a rg | e t    | T a rg e t  |        |
| --- | -------- | ------- | ----------------- | -------- | --- | ------ | ------ | ----------- | ------ |
|     | 7 ’h 7 E |         |                   |          | D a | ta     | D a ta |             | D a ta |
S / W  / A C K C C C B y te S r A d d re s s / T S r A d d re s s / T S r A d d re s s / T P
|     |     | / T       | / T                       | / R nW  / A | C K | / R nW  / A | C K | / R nW  / A C | K   |
| --- | --- | --------- | ------------------------- | ----------- | --- | ----------- | --- | ------------- | --- |
|     |     | C o m m a | n d  D e s c rip to r # 1 |             |     |             |     |               |     |
(A d d re s s,  C C C ,  D e fB y te , D a ta ) v a lid , T O C = 0 C oC m m a n d  D e s c rip to r # 3
|        |                                        |            |                       |      |                 |                               | (A d d re       | s s, C C ,  D e fB y te | , D a ta ) v a lid , T O C = 1 |
| ------ | -------------------------------------- | ---------- | --------------------- | ---- | --------------- | ----------------------------- | --------------- | ----------------------- | ------------------------------ |
| L eg e | n d Im plicitly driven, required for C |            | C C  fram ing         |      | C o m           | m a n d  D e s c rip to r # 2 |                 |                         |                                |
|        | Based on C                             | om m and D | escriptor param eters | (A d | d re s s, C C C | ,  D e fB y te , D a ta ) v a | lid , T O C = 0 |                         |                                |
|        | C ontinue or end, based on TO          |            | C field               |      |                 |                               |                 |                         |                                |
1051
Figure 10 Direct CCC Commands Framing Model: Example 4
| 34  |     |     |     | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     |     |     |
| --- | --- | --- | --- | ------------------------------------- | --- | --- | --- | --- | --- |
|     |     |     |     | Public Release Edition                |     |     |     |     |     |

Version 1.0 Specification for I3C TCRI
24-May-2022
6.3.2 Mixing Direct and Broadcast CCCs
1052 The Application may also use the TOC field to indicate continuous framing with multiple consecutive
1053 Command Descriptors, in order to compose larger transfers in CCC framing which might include Broadcast
1054 CCCs in addition to Direct CCCs, in any valid sequence allowed for CCCs in SDR Mode. The I3C Controller
1055 shall inspect the CCC related field values for such Command Descriptors, and handle the transitions
1056 appropriately (i.e., from a Broadcast CCC message to a Direct CCC segment, and from a Direct CCC segment
1057 to a Broadcast CCC message) according to the flows for CCC framing in SDR Mode.
1058 Each Command Descriptor shall either indicate a Target Address (or Group Address, if allowed) for Direct
1059 CCCs, or use a Broadcast CCC value with an appropriate field value to address all Devices on the I3C Bus.
1060 To send a Broadcast CCC, the Command Descriptor structure shall have the following properties:
1061 • The Command Attribute (CMD_ATTR) field shall be set to an appropriate value for a Transfer Command,
1062 specific to the Transfer Command type (see Section 7.1.2 and Section 7.2.2)
1063 • The DEV_INDEX field shall be set to zero, per Section 6.2
1064 • Specific other fields shall indicate a CCC-type transfer (i.e., segment), per the Transfer Command type:
1065 • For an Immediate Data Transfer Command, see Section 7.1.2.1.1 and Section 7.2.2.1.1
1066 • For a Regular Data Transfer Command, see Section 7.1.2.2.1 and Section 7.2.2.2.1
1067 • Note that Broadcast CCCs are in the range 0x00–0x7F, per the I3C Specification at Section 5.1.9.3
1068 [MIPI02].
1069 The I3C Controller shall interpret the fields in each Command Descriptor according to this model, and drive
1070 all necessary framing elements, including restarting CCC framing as needed, without any special Command
1071 Descriptors or other actions from the Application to handle the lower-level I3C framing elements for CCCs
1072 in SDR Mode.
Copyright © 2022 MIPI Alliance, Inc. 35
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.3.3 Error Handling for CCC Flows
1073 Each segment or phase of CCC flows (i.e., transfers in a continuous sequence) shall be processed and reported
1074 individually, per the setting of field WROC in each Command Descriptor that comprises the flow(see
1075 Section 6.2.2). However, Applications should generally set field WROC to 1’b1 to receive Response
1076 Descriptors for each segment or phase.
1077 For Command Descriptors describing Direct CCC segments, a Target might choose to NACK the Direct CCC
1078 sent to its Dynamic Address. If this occurs, and if the Direct CCC has been retried according to the NACK
1079 retry count, then the Response Descriptor shall indicate this result using a value of 0x5 (NACK) in field
1080 ERR_STATUS. Note that a Target Device would typically NACK its Dynamic Address, for any CCCs (or any
1081 CCCs with a particular Defining Byte value) that it does not support.
1082 For Direct CCC segments that address a Group (i.e., a Direct Write or Direct SET CCC), all Targets that are
1083 assigned to the Group Address and that support the CCC may choose to respond to the Direct CCC segment
1084 and ACK the Group Address; however, if none of these Targets choose to respond, then the I3C Bus
1085 Controller Logic shall treat this as a NACK of the Group Address, and shall retry the Direct CCC according
1086 to the NACK retry count for the Group (i.e., as with a Direct CCC that is sent to a Dynamic Address).
1087 For Command Descriptors describing Broadcast CCC messages, if no Targets ACK the Broadcast Address,
1088 then this is a CCC framing error, and the Response Descriptor shall indicate this result using a value of 0x4
1089 (ADDR_HEADER) in field ERR_STATUS. This might also occur for Direct CCCs, if a Command Descriptor
1090 requires the I3C Controller to re-send the Broadcast Address (per the conditions above).
1091 If any Command Descriptor in the middle of such a sequence of multiple consecutive Command Descriptors
1092 results in an error, then the I3C Controller shall stop processing the sequence early, end the CCC framing and
1093 drive a STOP condition, and allow the Application to run an error recovery procedure.
1094 Note:
1095 After stopping the sequence due to an error, the I3C Controller shall leave the I3C Bus in a valid state
1096 (i.e., STOP condition) and wait for the Application to handle the error. This might require the
1097 Application to determine which error occurred and initiate an error recovery procedure (i.e., by driving
1098 an HDR Exit Pattern).
36 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6.3.4 Mixing CCCs and Private Read/Write Transfers
1099 The Application may also use field TOC to indicate continuous framing with multiple consecutive Command
1100 Descriptors, to compose larger transfers in CCC framing which might include CCCs in addition to Private
1101 Read/Write transfers, in any valid sequence allowed by SDR Mode framing. The I3C Controller shall inspect
1102 the field values for such Command Descriptors, and handle the transitions appropriately (i.e., from a CCC
1103 message/segment to a Private Read/Write transfer, and from a Private Read/Write transfer to a CCC
1104 message/segment) according to the flows for starting and ending CCC framing in SDR Mode.
1105 In this manner, if a Command Descriptor’s field TOC is 0, the I3C Controller shall drive a Repeated START
1106 at the end of the transfer or message/segment, and shall also drive other necessary framing elements,
1107 depending on the transfer type and related field values for this Command Descriptor as well as the next
1108 Command Descriptor.
1109 • Transition from Private Read/Write to CCC: If this Command Descriptor indicated a Private
1110 Read/Write transfer, and the next Command Descriptor indicates a CCC, the I3C Controller shall start the
1111 CCC framing automatically, by driving a Repeated START condition, followed by the Broadcast Address
1112 (i.e., 7’h7E), then the Command Code in the next Command Descriptor.
1113 • If the next Command Descriptor indicates that a Defining Byte is present, the I3C Controller shall send
1114 the Defining Byte.
1115 • If the next Command Descriptor indicates a Direct CCC, then the I3C Controller shall drive another
1116 Repeated START condition to continue in CCC framing, followed by the Dynamic Address of the
1117 Target Address (or Group Address, if applicable) indicated in the next Command Descriptor, per CCC
1118 framing.
1119 • Transition from CCC to Private Read/Write: If this Command Descriptor indicated a CCC, and the next
1120 Command Descriptor indicates a Private Read/Write transfer, the I3C Controller shall end the CCC
1121 framing automatically, in an appropriate manner for the End of CCC Command (as defined in the I3C
1122 Specification at Section 5.1.9.2.1 [MIPI02]).
1123 • If this Command Descriptor was a Direct CCC, then the I3C Controller shall drive a Repeated START,
1124 followed by the Broadcast Address (i.e., 7’h7E), followed by another Repeated START to exit the
1125 Direct CCC framing in SDR Mode.
1126 • If this Command Descriptor was a Broadcast CCC, then the I3C Controller shall drive a Repeated
1127 START, since the I3C Bus does not remain in CCC framing after a Broadcast CCC.
1128 Note:
1129 Additional requirements shall also apply, per the I3C Controller’s supported Command Descriptor
1130 format (see Section 7).
Copyright © 2022 MIPI Alliance, Inc. 37
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.3.5 Support for HDR Modes
1131 This Managed CCC Framing Model may also be used to send CCCs in HDR Modes, if the I3C Controller
1132 supports transfers in at least one HDR Mode, and if the I3C Controller supports a Command Descriptor
1133 format that enables CCCs in HDR Modes.
1134 Note:
1135 If the I3C Controller does not support transfers in at least one HDR Mode or if it does not support a
1136 Command Descriptor format that enables CCCs in HDR Modes, then it shall only support CCC
1137 framing in SDR Mode. In this case, if the value of field MODE changes between two consecutive
1138 Command Descriptors in a sequence (i.e., if the first such Command Descriptor indicates SDR Mode
1139 and the value of field TOC is 1’b0) and the second Command Descriptor transitions from SDR Mode
1140 to a supported HDR Mode, then the I3C Bus Controller Logic shall automatically end the CCC framing
1141 in SDR Mode, and enter the indicated HDR Mode for generic HDR Write or HDR Read transfers (as
1142 per Section 6.2.5).
1143 An I3C Controller that fully supports Managed CCC Framing in one or more HDR Modes shall automatically
1144 enter the appropriate HDR Mode to send CCCs in that HDR Mode, when the Application enqueues a
1145 Managed CCC Transfer Command that indicates HDR Mode, using field MODE. This enables transition
1146 between I3C Modes, i.e., between SDR Mode and an HDR Mode. However use of such Transfer Commands
1147 does not support transitions between two different HDR Modes, or from HDR Mode to SDR Mode.
1148 The Application may also use multiple consecutive Transfer Commands in any HDR Mode, in order to drive
1149 sequences of Broadcast CCCs, Direct CCCs, or any combination of both. This works similarly to the model
1150 for SDR Mode (see Section 6.3.2): if a Transfer Command’s field TOC is 0, then the I3C Controller shall
1151 drive the HDR Restart Pattern at the end of the message/segment. However, in any HDR Mode the
1152 Application must use the appropriate End of CCC Procedures, by enqueueing the special Transfer Command
1153 to end the CCC framing in that HDR Mode.
1154 The I3C Controller shall also drive other necessary framing elements, depending on the transfer type and
1155 related field values for the supported Command Descriptor format as well as the next enqueued Command
1156 Descriptor.
1157 • Transition from Generic HDR-x Read/Write to HDR-x CCC: If this Command Descriptor indicated a
1158 Generic HDR-x Read/Write transfer (i.e., not a Managed CCC Transfer Command type), and the next
1159 Command Descriptor is a Managed CCC Transfer Command, then the I3C Controller shall start the CCC
1160 framing automatically by driving the HDR Restart Pattern followed by the appropriate HDR-x Header
1161 Block of type ‘Indicator’ containing the Command Code and optional Defining Byte in the next
1162 Command Descriptor.
1163 • The I3C Controller shall detect this based on the changing values of field CMD_ATTR.
1164 • If the next Command Descriptor indicates that a Defining Byte is present, then the I3C Controller shall
1165 send the Defining Byte.
1166 • If the next Command Descriptor indicates a Direct CCC in HDR Mode, then the I3C Controller shall
1167 drive another HDR Restart Pattern to continue in CCC framing, followed by the appropriate HDR-x
1168 Header Block of type ‘Selector’ containing the Target Address (or Group Address, if applicable)
1169 indicated in the next Command Descriptor, per CCC framing.
1170 • Transition from HDR-x CCC to Generic HDR-x Read/Write: If this Command Descriptor is a Managed
1171 CCC Transfer Command, and the next Command Descriptor indicates a Generic HDR-x Read/Write
1172 transfer (i.e., not a Managed CCC Transfer Command type), then the I3C Controller shall ensure that the
1173 CCC framing was ended appropriately.
1174 • For all CCCs in HDR Modes: The Application shall first end the framing by sending a special
1175 Managed CCC Transfer Command to end the CCC framing.
1176 • If the Application has not previously ended the framing (i.e., if this Command Descriptor is a CCC
1177 message/segment in an HDR Mode), then this is an error and the I3C Controller shall return an error
1178 code in the Response Descriptor for the next Command Descriptor. The Application shall
1179 accommodate this returned status in its error handling flow, using the error codes defined in
38 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
1180 Section 6.4.1. The specific error code shall be 0xC (Transfer Type Specific:
1181 CCC_FRAMING_NOT_ENDED) in field ERR_STATUS.
1182 • If the Application has ended the framing (i.e., if this Command Descriptor is a special Managed CCC
1183 Transfer Command to end the framing in that HDR Mode), then the I3C Controller and I3C Bus
1184 Controller Logic shall end the CCC framing automatically in an appropriate manner for the HDR-x
1185 End of CCC Procedure (as defined in the I3C Specification at Section 5.2.1.2 [MIPI02]). The I3C
1186 Controller shall then proceed to the Generic HDR-x Read/Write transfer indicated by the next
1187 Command Descriptor.
1188 For all the requirements defined for the flow above, the Application shall not change the value of field MODE
1189 in all such Command Descriptors, in order to ensure that the I3C Controller does indeed remain in the same
1190 HDR Mode. Note that the term “HDR-x” serves as a placeholder for a specific HDR Mode, and that the
1191 generic CCC flows in HDR Modes (as defined in the I3C Specification at Section 5.2.1.2 [MIPI02]) serve
1192 as representative examples of the CCC flow requirements and definitions for specific HDR Modes.
1193 For Managed CCC flows, several differences apply between SDR Mode and all HDR Modes:
1194 • Broadcast CCCs in SDR Mode do not require a Managed CCC Transfer Command to end the CCC
1195 framing and return to Private Read/Write transfers. However, Broadcast CCCs in HDR Modes always
1196 require a special Managed CCC Transfer Command to end the CCC framing and return to Generic
1197 Read/Write transfers in that same HDR Mode.
1198 • The specific End of CCC Procedure for a given HDR Mode may vary, given the circumstances.
1199 However, the Managed CCC Framing Model abstracts these differences and provides a special form of
1200 Managed CCC Transfer Command to use, regardless of the HDR Mode.
Copyright © 2022 MIPI Alliance, Inc. 39
Public Release Edition

Specification for I3C TCRI  Version 1.0
  24-May-2022
6.4  Error Handling
1201  The general approach to error handling in the I3C Transfer Command/Response Interface is as follows:
1202  • Any detectable error on a transaction (e.g., a NACK) will result in an error code in the Response
1203  Descriptor structure. Reception of the Response triggers an interrupt to the Application.
In addition, the I3C Controller shall halt processing to allow the Application to handle the error.
1204
1205  • The specific error code shall be returned in field ERR_STATUS of the Response Director, as defined in
Section 7.1.3 (for Format 1) and Section 7.2.3 (for Format 2). Subsequent sections contain additional
1206
1207  details on the defined error codes in field ERR_STATUS.
• The Application is responsible for deciding how to handle the error. This includes invoking error
1208
1209  recovery procedures, resuming processing from the next Transfer Command that was enqueued,
1210  retrying the Transfer Command that caused the error, or clearing (i.e., emptying) the Command Queue
1211  in order to receive new Transfer Commands from the Application.
1212  • For Write requests, the Application should issue a Transfer Command with the GETSTATUS Direct CCC
to determine the Device’s overall error status.
1213
1214  • For In-Band Interrupt requests, the Application will report these in an Application-defined manner.
1215  The I3C Controller shall not autonomously issue the GETSTATUS Direct CCC, nor issues any other
command, to determine Device state/health. The Application shall issue GETSTATUS Direct CCC when
1216
1217  required, and shall subsequently take appropriate measures to recover the Bus or the I3C Controller.
1218  Upon any non-recoverable internal error, the I3C Controller shall stop processing of Transfer Commands and
immediately report the error to the Application.
1219
1220  Note:
Specific Applications may choose to define additional error handling schemes on receiving a
1221
1222  detectable error in a Response Descriptor, or via other means.
6.4.1  Error Status Codes in Response Descriptor
1223  The error codes listed in Table 1 and detailed in the following sub-sections are defined in Table 11 for error
1224  status indication of a Command Transfer in Active Controller mode:
Table 1 Error Status Codes in Response Descriptor
1225
|     | ERR_STATUS  | Detailed in   |
| --- | ----------- | ------------- |
Error Code
|                     | Value  | Sub-Section  |
| ------------------- | ------ | ------------ |
| CRC                 | 0x1    | 6.4.1.1      |
| PARITY              | 0x2    | 6.4.1.2      |
| FRAME               | 0x3    | 6.4.1.3      |
| ADDR_HEADER         | 0x4    | 6.4.1.4      |
| NACK                | 0x5    | 6.4.1.5      |
| OVL                 | 0x6    | 6.4.1.6      |
| I3C_SHORT_READ_ERR  | 0x7    | 6.4.1.7      |
HC_ABORTED
|     | 0x8  | 6.4.1.8  |
| --- | ---- | -------- |
I2C_WR_DATA_NACK
| or  | 0x9  | 6.4.1.9  |
| --- | ---- | -------- |
BUS_ABORTED
| NOT_SUPPORTED           | 0xA        | 6.4.1.10  |
| ----------------------- | ---------- | --------- |
| ABORTED_WITH_CRC        | 0xB        | 6.4.1.11  |
| Transfer Type Specific  | 0xC – 0xF  | 6.4.1.12  |
40  Copyright © 2022 MIPI Alliance, Inc.
  Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
6.4.1.1 CRC
1226 For field ERR_STATUS having a value of 0x1 (CRC):
1227 • In HDR-DDR Mode:
1228 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a CRC error by inspecting the
1229 CRC5 checksum provided by the addressed Target Device in the HDR-DDR CRC Word. If the
1230 provided checksum does not match the computed checksum for the received payload data, then this is
1231 a CRC error (per version 1.1.1 of the I3C Specification [MIPI02] at Section 5.2.2.4).
1232 • In HDR-BT Mode:
1233 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a CRC error by inspecting the
1234 CRC checksum (either CRC-16 or CRC-32 according to the HDR-BT Header Block) provided by the
1235 addressed Target Device in the HDR-BT CRC Block. If the provided checksum does not match the
1236 computed checksum for the received payload data, then this is a CRC error (per version 1.1.1 of the
1237 I3C Specification [MIPI02] at Section 5.2.4.3.3).
1238 • For Generic Write transfers, the I3C Bus Controller Logic shall detect cases where a Target Device
1239 indicates a CRC mismatch or a failure to verify the Write transfer, by watching SDA[0] during the
1240 Transition_Verify byte of the HDR-BT CRC Block. If the Target Device does not drive SDA[0] Low,
1241 then this indicates a CRC error or other failure to verify the Write transfer, as detected by the Target
1242 Device (per version 1.1.1 of the I3C Specification [MIPI02] at Section 5.2.4.3.3).
1243 • If the Write transfer was allowed to complete normally, then the I3C Controller shall report this as a
1244 verification error due to CRC mismatch.
1245 • If the Write transfer was aborted early, then the I3C Controller shall report this as an Aborted with
1246 CRC Error (see Section 6.4.1.11).
6.4.1.2 PARITY
1247 For field ERR_STATUS having a value of 0x2 (PARITY):
1248 • In HDR-DDR Mode:
1249 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Parity error by inspecting the
1250 Parity bits (i.e., PA1, PA0) for all HDR-DDR Words provided by the Target Device. If the provided
1251 Parity bits are not correct, then this is a Parity error per version 1.1.1 of the I3C Specification
1252 [MIPI06] at Section 5.2.2.4.
1253 • In HDR-TSP/TSL Mode:
1254 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Parity error by inspecting the
1255 Parity bits from the decoded HDR-Ternary Data Word. If the provided Parity bits are not correct, then
1256 this is a Parity error (per version 1.1.1 of the I3C Specification [MIPI02] at Section 5.2.3.4).
1257 • In HDR-BT Mode:
1258 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Parity error by inspecting
1259 Bit[3] in the Transition_Control byte provided by the addressed Target Device in an HDR-BT Data
1260 Block. If the provided parity bit does not match the computed parity bit for the other bits in the
1261 Transition_Control byte, then this is a Parity error (per version 1.1.1 of the I3C Specification [MIPI02]
1262 at Section 5.2.4.3.2).
1263 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Parity error by inspecting
1264 Bit[3] in the Control byte provided by the addressed Target Device in the HDR-BT CRC Block. If the
1265 provided parity bit does not match the computed parity bit for the other bits in the Control byte, then
1266 this is a Parity error (per version 1.1.1 of the I3C Specification [MIPI02] at Section 5.2.4.3.3).
Copyright © 2022 MIPI Alliance, Inc. 41
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.4.1.3 FRAME
1267 For field ERR_STATUS having a value of 0x3 (FRAME):
1268 • In HDR-DDR Mode:
1269 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Framing error by inspecting
1270 the 2 Preamble bits (i.e., PRE1, PRE0) at the start of every HDR-DDR Word provided by the Target
1271 Device. If the Preamble bits are incorrect, or if the format and length of the HDR-DDR Word is
1272 malformed based on the indicated Preamble bits, then this is a Framing error (per version 1.1.1 of the
1273 I3C Specification [MIPI02] at Section 5.2.2.4).
1274 • The I3C Bus Controller Logic shall also detect a Framing error if the provided HDR-DDR Words
1275 appear in an incorrect sequence for HDR-DDR framing, or if a CRC Word contains a first nibble
1276 having a value other than 4’hC, or if a Reserved Word is used.
1277 • In HDR-TSP/TSL Mode:
1278 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Framing error if it receives
1279 certain types of illegal Bus activity driven by the Target Device. For example, if the I3C Bus Controller
1280 Logic receives two instances of Symbol 2 within the same HDR-Ternary Data Word, then this is a
1281 Framing error (per version 1.1.1 of the I3C Specification [MIPI02] at Section 5.2.3.4).
1282 • In HDR-BT Mode:
1283 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Framing error by inspecting
1284 the Transition_Control byte provided by the addressed Target Device in an HDR-BT Data Block. If the
1285 Park1 on SDA[0] is not 1, then this is a Framing error (per version 1.1.1 of the I3C Specification
1286 [MIPI02] at Section 5.2.4.3.2).
1287 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a Framing error by inspecting
1288 the Control byte provided by the addressed Target Device in the HDR-BT CRC Block. If any of the
1289 following conditions are detected, then this is a Framing error (per version 1.1.1 of the I3C
1290 Specification [MIPI02] at Section 5.2.4.3.3):
1291 • If Provided Bit[0] is not 0;
1292 • If Provided Bit[1] is not 0;
1293 • If Provided Bit[5] does not have the same value that was sent in the Control Byte for the HDR-BT
1294 Header Block for this transfer; or
1295 • If Provided Bit[6] does not match the expected value (for the transaction expected to be terminated
1296 early, compared with the last HDR-BT Data Block marked as Last).
6.4.1.4 ADDR_HEADER
1297 For field ERR_STATUS having a value of 0x4 (ADDR_HEADER):
1298 • In SDR Mode:
1299 • If no Target Devices acknowledge the Broadcast Address (i.e., 7’h7E) driven automatically by the I3C
1300 Bus Controller Logic at the start of CCC framing (per Section 6.3), then this is an Address Header
1301 error (see version 1.1.1 of the I3C Specification [MIPI02] at Section 5.1.9.1).
1302 • If no Target Devices acknowledge the Broadcast Address before the start of a private Transfer
1303 Command, driven automatically by the I3C Bus Controller Logic after every START, then this is an
1304 Address Header error. The Application may configure the I3C Controller to use START / 7’h7E before
1305 every private Transfer Command, which allows for IBI reception (see Section 6.2.6).
1306 • If no Target Devices acknowledge the Broadcast Address at any other time for SDR framing where it is
1307 appropriate for the I3C Bus Controller Logic to automatically drive the Broadcast Address for any
1308 reason, then this is an Address Header error.
1309 Note:
1310 In SDR Mode, any other I3C Target Device could attempt to drive its Dynamic Address onto the
1311 I3C Bus during the Arbitrable Address Header after a START (but not a Repeated START). In
1312 cases where another I3C Target Device’s Dynamic Address wins the Address Arbitration (i.e.,
1313 during an Interrupt Request or when sending the Broadcast Address), this shall not be an
1314 Address Header error. The I3C Controller shall process this as an incoming interrupt request,
42 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
1315 and it shall either defer processing of the Transfer Command until after the STOP (and
1316 subsequent Bus Free Condition), or after the Repeated START following the Interrupt Request.
1317 Refer to the I3C Specification [MIPI02] at Section 5.1.2.2.
1318 • In any HDR Modes:
1319 • For generic transfers in any HDR Mode, if no Target Devices that support this specific HDR Mode
1320 actively acknowledge the HDR write command that is addressed to the Broadcast Address (i.e.,
1321 7’h7E), then this is an Address Header error. Note that an HDR write command addressed to the
1322 Broadcast Address is only used for CCCs in HDR Modes, per [MIPI02] at Section 5.2.2.2.1.
6.4.1.5 NACK
1323 For field ERR_STATUS having a value of 0x5 (NACK):
1324 • During Dynamic Address Assignment with ENTDAA:
1325 • If any Target Device that responds to the ENTDAA procedure (i.e., that is initiated by an Application-
1326 specific Address Assignment Command) does not accept the Dynamic Address that it has been
1327 assigned, then this is a NACK error.
1328 • In SDR Mode:
1329 • If an addressed Target Device does not acknowledge its Dynamic Address for a Private Write/Read
1330 transfer, or for a Direct CCC transfer (per Section 6.3), and the maximum number of retries has been
1331 exceeded, then this is a NACK error.
1332 • Similar conditions apply to Private Write transfers and Direct SET CCC flows addressing a Group
1333 Address, if none of the Target Devices assigned to that Group Address acknowledge the transfer.
1334 • In any HDR Modes:
1335 • If an addressed Target Device that supports this specific HDR Mode does not actively acknowledge its
1336 Dynamic Address in the appropriate Block or Word for that HDR Mode, for a Generic HDR
1337 Read/Write transfer or a Direct CCC flow in that HDR Mode, then this is a NACK error.
1338 • Similar conditions apply to Generic HDR Write transfers and Direct SET CCC flows addressing a
1339 Group Address, if none of the Target Devices assigned to that Group Address acknowledge the
1340 appropriate Block or Word in that HDR Mode.
6.4.1.6 OVL
1341 For field ERR_STATUS having a value of 0x6 (OVL):
1342 • This error code is reserved for Application-specific errors that deal with data underflow conditions (i.e.,
1343 for Write-type transfers), or data overflow conditions (i.e., for Read-type transfers).
1344 • While this Specification does not define a data transfer mechanism for an Application, the implementer
1345 must define a data TX/RX for Write-type or Read-type transfers. If the I3C Controller runs out of
1346 Application-provided TX data during a Write-type transfer, or if the Application does not consume RX
1347 data during a Read-type transfer, the I3C Controller shall terminate the transfer and report this error.
1348 • This error code may also be used for Application-specific errors that deal with special sequences of
1349 Transfer Commands.
1350 • This may include special framing of Transfer Commands (i.e., Atomic transactions) that might be
1351 framed by Application-defined Internal Control Commands for special purposes. Some of these uses
1352 could include reporting the failure of such an Atomic transaction if the I3C Controller experiences an
1353 unexpected Command Sequence Underflow error (i.e., if the Application is unable to provide all such
1354 Transfer Commands in time to prevent a stall or timeout on the I3C Bus).
Copyright © 2022 MIPI Alliance, Inc. 43
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.4.1.7 I3C_SHORT_READ_ERR
1355 For field ERR_STATUS having a value of 0x7 (I3C_SHORT_READ_ERR):
1356 • For I3C Read-Type transfers in any I3C Mode:
1357 • The I3C Controller shall report this error code for I3C Read-Type transfers that did not return the
1358 requested number of data bytes (i.e., ‘short’ Read-Type transfers, per Section 6.2.7) when the Transfer
1359 Command indicated that a ‘short’ Read-Type transfer was not permitted. The I3C Controller shall also
1360 halt operations and treat this as a transfer error.
1361 Note:
1362 For Transfer Commands in I3C Mode, a ‘short’ Read-Type transfer, where the I3C Target Device
1363 returns fewer bytes than expected, does not necessarily indicate an I3C Bus error. However, since
1364 the Transfer Command indicated that a ‘short’ Read-Type transfer was not allowed (per
1365 Section 7.1.2.2 and Section 7.2.2.2), the I3C Controller must treat this as an error and halt
1366 operations so that the Application can resolve the situation.
6.4.1.8 HC_ABORTED
1367 For field ERR_STATUS having a value of 0x8 (HC_ABORTED):
1368 • The I3C Controller shall report this error code for a transaction that was aborted due to an abort
1369 operation that was sent by the Application during a transfer. The method for aborting a transaction is
1370 defined by the Application.
6.4.1.9 I2C_WR_DATA_NACK or BUS_ABORTED
1371 For field ERR_STATUS having a value of 0x9, the interpretation of this error code depends on whether this is
1372 an I2C transfer or an I3C transfer:
1373 • In SDR Mode for I2C transfer speeds:
1374 • The I3C Controller shall report error code I2C_WR_DATA_NACK for I2C write data transactions, where
1375 the I2C Target Device does not acknowledge the transfer.
1376 • For I3C transfers in SDR Mode or HDR Modes (except HDR-BT Mode):
1377 • The I3C Controller shall report error code BUS_ABORTED for:
1378 • A transaction that was aborted due to Early Termination (which might have been caused by a
1379 Monitoring Device on the I3C Bus); or
1380 • A transaction that ended early, due to a Target Device not completing the data phase of the transfer.
1381 This is not the same as a I3C Controller initiated transfer abort (i.e., termination) that would be
1382 indicated by field ERR_STATUS having a value of 0x8 (HC_ABORTED).
1383 • For I3C transfers in HDR-BT Mode:
1384 • For Generic Read transfers, the I3C Bus Controller Logic shall detect a transaction terminated early by
1385 inspecting the Control byte provided by the addressed Target Device in the HDR-BT CRC Block. If
1386 any of the following conditions are detected, then this is a Framing error (per version 1.1.1 of the I3C
1387 Specification [MIPI02] at Section 5.2.4.3.3):
1388 • If Provided Bit[6] does not match the expected value for the transaction that was expected to be
1389 continued, where the previous HDR-BT Data Block was not marked as Last.
1390 • Any other method of aborting a Read transaction before expected completion.
1391 • For Generic Write transfers, the I3C Bus Controller Logic shall detect cases where a Target Device
1392 wishes to terminate the Write transaction early, and drives SDA[0] Low during the Transition_Control
1393 byte (i.e., the first byte) of the HDR-BT Data Block. If this happens, then the I3C Controller shall
1394 terminate the transmission and shall send an HDR-BT CRC Block (per version 1.1.1 of the I3C
1395 Specification [MIPI02] at Section 5.2.4.3.2).
1396 • The I3C Controller shall report this as an aborted transaction with error code BUS_ABORTED, unless
1397 the Target Device also reports a CRC mismatch (see Section 6.4.1.1). In that case, the I3C Controller
1398 shall report this as a combined error, i.e., Aborted with CRC (i.e., error code ABORTED_WITH_CRC,
1399 see Section 6.4.1.11).
44 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
1400 Note:
1401 The I3C Controller shall report other values in field ERR_STATUS for Combo Transfer Commands if
1402 such Transfer Commands are aborted on the Bus, during phases other than the first phase (see
1403 Section 6.4.1.11, Section 7.1.2.3, and Section 7.2.2.3).
6.4.1.10 NOT_SUPPORTED
1404 For field ERR_STATUS having a value of 0xA (NOT_SUPPORTED):
1405 • In any mode:
1406 • The I3C Controller shall report this error code for any Command Descriptor with an illegal or
1407 invalid combination of field values.
6.4.1.11 ABORTED_WITH_CRC
1408 For field ERR_STATUS having a value of 0xB (ABORTED_WITH_CRC):
1409 • In HDR-BT Mode:
1410 • For Generic Write transfers, the I3C Bus Controller Logic shall detect cases where a Target Device
1411 wishes to terminate the Write transaction early, and then subsequently indicates that the CRC that it
1412 received in the following HDR-BT CRC Block does not match the computed checksum for the
1413 received payload data (per Section 6.4.1.1). In the special case where both of these events happen in
1414 the same Write transaction, the I3C Controller shall report this as an Aborted with CRC Error.
6.4.1.12 Transfer Type Specific
1415 For field ERR_STATUS having a value of 0xC – 0xF (Transfer Type Specific):
1416 These error codes are used for special variants of Transfer Commands, or in other operating modes.
1417 • While processing a Combo Transfer Command:
1418 • The I3C Controller shall report error codes 0xC or 0xD if the I3C Bus Controller Logic encounters an
1419 error or unexpected condition during the second phase of a Combo transfer, as defined in
1420 Section 7.1.2.3 and Section 7.2.2.3. The specific error code depends on the type of error that the I3C
1421 Bus Controller Logic detects:
1422 • Error code 0xC (Transfer Type Specific: COMBO_NACK_2ND) is equivalent to NACK for the second
1423 phase.
1424 • Error code 0xD (Transfer Type Specific: COMBO_BUS_ABORTED_2ND) is equivalent to
1425 BUS_ABORTED for the second phase.
1426 • For Combo transfers, error codes 0x5 (NACK) and 0x9 (BUS_ABORTED) shall apply only to the first
1427 phase of the transfer (i.e., the initial Write operation).
1428 • While processing a sequence of Command Descriptors for an Atomic transaction:
1429 • The I3C Controller shall report error codes 0xC or 0xD for an Application-defined special Internal
1430 Control Command that indicates the end of such a sequence, if the Atomic transaction failed due to
1431 early cancellation by the Application, or the Command Queue had an underflow condition before the
1432 end of the sequence (i.e., if the Application could not enqueue all such Command Descriptors in a
1433 timely manner, to maintain continuous framing and avoid a timeout). However, this I3C TCRI
1434 Specification does not define any specific Internal Control Commands for such purposes.
1435 • If the Command Queue underflow condition occurs, then any individual Transfer Commands that were
1436 rejected (i.e., not driven on the I3C Bus due to underflow) shall report error code 0x8 (HC_ABORTED).
1437 • For other transfer errors, the usual error codes shall apply to the individual Transfer Commands within
1438 the sequence.
1439 • While processing a sequence of Managed CCC Transfer Commands:
1440 • The I3C Controller shall report error code 0xC (CCC_FRAMING_NOT_ENDED) if the next Command
1441 Descriptor is not a Managed CCC Transfer Command type, and the CCC framing has not been ended
1442 appropriately as defined in Section 6.3.4 for SDR Mode and Section 6.3.5 for HDR Modes. This error
1443 is only reported if the I3C Controller supports Managed CCC Transfer Commands.
Copyright © 2022 MIPI Alliance, Inc. 45
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
6.4.2 Errors Due to Command Sequence Stall or Timeout
1444 In some situations, the I3C Controller might fully drain the Command Queue while processing a command
1445 sequence where one or more Command Descriptors were enqueued into the Command Queue, with the last
1446 Command Descriptor being a Transfer Command having field TOC=0. As the I3C Bus Controller Logic
1447 started processing these enqueued Transfer Commands, the Application might not enqueue another suitable
1448 Command Descriptor having field TOC=1 in a timely manner, and the I3C Bus Controller Logic was forced
1449 to terminate the sequence.
1450 • In SDR Mode, the I3C Bus Controller Logic might stall the Bus at certain points in SDR framing,
1451 according to the maximum allowed stall times defined for SCL Low (see the I3C Specification [MIPI02]
1452 at Section 5.1.2.5).
1453 • In HDR Modes, the I3C Bus Controller Logic might use a stall method that is specific to that HDR
1454 Mode, if supported and previously enabled for use.
1455 • If the stall method was not previously enabled, or if no stall method is supported, then the I3C
1456 Controller must terminate the transaction with the HDR Exit Pattern.
1457 If a stall condition is permitted, then the I3C Bus Controller Logic might recover from a stall if the
1458 Application enqueues a new Command Descriptor before the maximum stall time, and if the Command
1459 Descriptor is a valid Transfer Command. However, if the stall condition continues to the maximum allowed
1460 time, then the I3C Bus Controller Logic must terminate the transaction with a STOP condition (for SDR
1461 Mode) or the HDR Exit Pattern (for HDR Modes).
1462 If the I3C Bus Controller Logic detects such a condition that it has temporarily mitigated by stalling the
1463 clock, then the I3C Controller shall report this as a warning event, to the Application. However, if the
1464 condition is not resolved, and the stall turns into a timeout, then the I3C Controller shall report this as a
1465 possible error to the Application. Both such notifications should be high-priority interrupts, although the
1466 specifics of such an interface are not defined in this Specification.
1467 The Application may subsequently resume sending valid Command Descriptors after the timeout, and the
1468 I3C Controller shall attempt to restart a new transaction in the indicated I3C Mode, starting with the next
1469 Transfer Command in the sequence, unless any of the following conditions are true:
1470 • The Response Descriptor for the previous Transfer Command (i.e., the last one processed before the stall
1471 turned into a timeout) indicated a transfer error in field ERR_STATUS;
1472 • The I3C Controller was processing Transfer Commands in a special Atomic transaction that had a
1473 timeout condition, and would reject any subsequent Transfer Commands after this timeout, until the
1474 Application sends a special command to end this transaction mode;
1475 • The I3C Controller was configured by the Application to halt operations on any Command Sequence
1476 Timeout; or
1477 • Any other transfer error or operational error was encountered.
1478 If the I3C Controller is configured to halt on any Command Sequence Timeout, then it must halt processing
1479 and wait for the Application to resolve the condition using an error recovery procedure. This is useful when
1480 the Application sends sequences of Command Descriptors that are Transfer Commands which must be run
1481 in sequence using continuous framing in order to be successful, i.e., for a particular I3C content protocol that
1482 does not tolerate a disruption (i.e., forced end of the framing) if certain successive transfers are to be
1483 successful.
1484 For example, in cases where an unresolved stall becomes a timeout that causes a STOP condition or
1485 HDR Exit Pattern, this would disrupt the operation of the addressed Target(s), or have other side
1486 effects on the operation of addressed Target(s) that require subsequent Transfer Commands to be
1487 continuously executed with any preceding Transfer Commands. If so configured, then the I3C
1488 Controller shall not execute any subsequent Transfer Commands after the forced STOP condition or
1489 HDR Exit Pattern.
1490 However, if the I3C Controller is not configured to halt on any Command Sequence Timeout, then it may
1491 generally resume processing without waiting for the Application to resolve the condition. This is useful when
46 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
1492 the Application sends standard Transfer Commands that may be executed separately or together, with the use
1493 of continuous framing as a performance optimization.
1494 In this case, an unresolved stall that becomes a timeout shall still be reported as an error, but the I3C
1495 Controller shall resume operation upon receiving the next enqueued Command Descriptor, unless the
1496 I3C Controller was processing a special sequence of Transfer Commands that did not allow
1497 automatic resume of operations, such as an Atomic transaction.
1498 Note:
1499 The Application may also define special Atomic transactions that always require the I3C Controller
1500 to halt on any Command Sequence Timeout condition.
Copyright © 2022 MIPI Alliance, Inc. 47
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
This page intentionally left blank.
48 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
7 Transfer Command/Response Structures
1501 This Section describes the standard data structures used for the I3C Transfer Command/Response Interface.
1502 These are presented as data structures.
1503 Two formats of structures are defined:
1504 Table 2 Command/Response Formats
Size (DWORDs) Defined in
Format Description (Command /
Section
Response)
1 Legacy Format, Indexed with DAT 2 / 1 7.1
2 Legacy Format, Direct Addressed 2 / 1 7.2
1505 Key differences between these Command/Response formats include:
1506 • Whether the Command Descriptor for I3C transfers requires an index to a particular DAT entry for a
1507 specific I3C Target (i.e., Format 1), or whether it directly contains the address of the I3C Target for the
1508 transaction (i.e., Format 2).
1509 • For Format 1: The DAT index is provided in a field that is 5 bits in size, allowing for up to 32 unique
1510 DAT entries in the I3C Application that can be used in Transfer Commands.
1511 • For Format 2: The Target device is provided in a field that is 7 bits in size, and the Application directly
1512 provides the Target’s Dynamic Address for transactions.
1513 • Whether the Target type (i.e., I3C vs I2C) must be defined in the DAT entry, or whether it is provided in a
1514 unique field (i.e., a single bit).
1515 • For Format 1: The Application’s DAT must have a bit field in each DAT entry, set for each Target that
1516 has an entry and that can be addressed with a Transfer Command. The I3C Bus Controller logic uses
1517 the bit field in the indicated DAT entry.
1518 • For Format 2: The Application’s DAT (if it has one) does not require such a bit field in each DAT
1519 entry, but the Transfer Command includes a field used by the I3C Bus Controller logic.
1520 Note:
1521 If the I3C Controller supports Format 2, then the I3C Application may (and should) still use a DAT to
1522 configure per-Target responses to particular I3C Bus events and conditions. When using Format 2,
1523 Legacy I2C Devices do not typically require individual DAT entries. However, the scope of the
1524 functionality that can be controlled by a particular Application’s DAT is not defined in this TCRI
1525 Specification.
1526 In all other respects, Format 1 and Format 2 provide equivalent functionality and the Application may choose
1527 either one, depending on the use case requirements.
Copyright © 2022 MIPI Alliance, Inc. 49
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
7.1 Format 1: Legacy Format, Indexed
1528 The size of this Command Descriptor format is 2 DWORDs. This Command Descriptor format matches the
1529 format that was defined in version 1.1 of the I3C HCI Specification [MIPI05], which enables selected new
1530 features that were added in version 1.1+ of the I3C Specification [MIPI06].
1531 The Command Descriptor is defined in Section 7.1.2 and supports several types of Transfer Commands, as
1532 well as the Internal Control type command, as indicated by the CMD_ATTR field. Transfers are limited to 64
1533 KB in size. For all Transfer Commands, the Command Descriptor includes a 5-bit DEV_INDEX field containing
1534 an index into the DAT table:
1535 • For private transfers and Direct CCCs: The I3C Controller shall fetch the Dynamic Address from the
1536 DAT entry indicated by the DEV_INDEX field. The Application shall provide a valid index to a DAT entry
1537 that has been populated with a valid Dynamic Address of a Device on the I3C Bus (or an assigned Group
1538 Address for Write-type transfers, if supported).
1539 • For Broadcast CCCs: The I3C Controller shall not use the DEV_INDEX field. The Application should set
1540 DEV_INDEX to 5’h00.
1541 Note:
1542 This Command Descriptor format does not support transfers using some of the new features enabled
1543 by version 1.1+ of the I3C Specification [MIPI06], such as HDR-BT (Bulk Transfer) Mode, Multi-Lane
1544 transfers in any supported I3C Modes, CCC flows in HDR Modes, or several types of Combo
1545 transfers that are necessary for specific use cases such as Device to Device Tunneling. A future
1546 version of this I3C TCRI Specification is expected to enable such features.
7.1.1 Common Aspects of Transfer Commands
7.1.1.1 I3C Modes and Data Rates
1547 An I3C Controller implementer may choose which I3C Modes to support. The following I3C Modes are
1548 provided as guidance.
1549 Table 3 Supported I3C Transfer Modes
MODE Value I3C Transfer Mode Support
0x0 – 0x4 I3C SDR Mode Required
0x5 I3C HDR-Ternary Modes Optional
0x6 I3C HDR-DDR Mode Optional
0x7 Reserved –
1550
1551 An I3C Controller implementer may choose differing interpretations for the specific data rates for values of
1552 the MODE field, which are used by the various Transfer Command types that the I3C Controller supports.
1553 Note:
1554 In this Command Descriptor format, the MODE field encodes both the transfer mode and the data
1555 rate.
1556 Depending on the implementation, the specific data rates for the available the options for I3C SDR Mode
1557 transfers might depend on the specific clock logic used within the I3C Controller, or other clock logic used
1558 within the System. The following guidelines are provided, based on the maximum values.
50 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0  Specification for I3C TCRI
24-May-2022
Table 4 Maximum Values for I3C SDR Data Transfer Speeds
1559
MODE
|     | Field  | Listed Speed  | Maximum Sustainable Data Rate  |     |
| --- | ------ | ------------- | ------------------------------ | --- |
Value
|     | 0x0  | I3C SDR0  | 12.5 MHz, Standard SDR Speed, fSCL Max   |     |
| --- | ---- | --------- | ---------------------------------------- | --- |
|     | 0x1  | I3C SDR1  | 8 MHz                                    |     |
|     | 0x2  | I3C SDR2  | 6 MHz                                    |     |
|     | 0x3  | I3C SDR3  | 4 MHz                                    |     |
|     | 0x4  | I3C SDR4  | 2 MHz                                    |     |

Specific user-defined data rates for the available options for I2C Mode transfers may also be implemented in
1560
1561  the I3C Controller.
| 1562  |     | Table 5 Maximum Values for I2C Data Transfer Speeds  |     |     |
| ----- | --- | ---------------------------------------------------- | --- | --- |
MODE
|     | Field  | Listed Speed  | Maximum Sustainable Data Rate  |     |
| --- | ------ | ------------- | ------------------------------ | --- |
Value
|     | 0x0  | I2C FM    | 400 KHz, I2C Fast Mode Speed, fSCL Max     |     |
| --- | ---- | --------- | ------------------------------------------ | --- |
|     | 0x1  | I2C FM+   | 1 MHz, I2C Fast Mode Plus Speed, fSCL Max  |     |
|     | 0x2  | I2C UDR1  | User Defined Data Rate 1                   |     |
I2C UDR2
|     | 0x3  |           | User Defined Data Rate 2  |     |
| --- | ---- | --------- | ------------------------- | --- |
|     | 0x4  | I2C UDR3  | User Defined Data Rate 3  |     |

1563  An I3C Controller implementer might choose to provide specific controls over the data rates used by the I3C
Bus Controller Logic, for various values supported by the MODE field in the various Transfer Command types
1564
1565  supported by the I3C Controller (see Section 7.1.2). If such parameters need to be controlled by the
1566  Application, then the implementer should define an interface to access these parameters. Note that such
1567  parameters for I3C SDR Mode timing might also include separate fields to affect the different transfer speeds
1568  for the Open-Drain vs. Push-Pull phases of I3C transactions in SDR Mode, including:
1569  • I3C Address Arbitration phase after a START condition
1570  • I3C Address Header after a Repeated START condition
1571  • Specific transfer rates for CCCs used during Bus Initialization and Dynamic Address Assignment:
1572  • SETDASA and SETAASA CCCs
1573  • ENTDAA CCC, including the various phases of the procedure with Dynamic Address Arbitration (per
the I3C Specification [MIPI02] at Section 5.1.4.2)
1574
For the various data rates, an implementer should also determine whether the I3C Controller and its I3C Bus
1575
1576  Controller Logic provide additional control over the clock speed (for I3C Pure Bus), or the duty cycle to limit
the effective minimum data rate (for I3C Mixed Buses) for specific Applications where the system requires
1577
1578  that the data rate stay above a given minimum transfer rate (per the I3C Specification  [MIPI02] at
1579  Section 5.1.2.4.1). If such control is needed, then the implementer should provide this control to the
Application via an interface.
1580
1581  An implementer should also define whether the I3C Controller supports Controller Clock Stalling (per the
1582  I3C Specification [MIPI02] at Section 5.1.2.5), and if so, whether such parameters that control Controller
Clock Stalling need to be controlled by the Application. If so, then the implementer should provide this
1583
1584  control to the Application via an interface.

|     |     | Copyright © 2022 MIPI Alliance, Inc.  |                         | 51  |
| --- | --- | ------------------------------------- | ----------------------- | --- |
|     |     |                                       | Public Release Edition  |     |

Specification for I3C TCRI Version 1.0
24-May-2022
7.1.1.2 Managed CCC Framing for Transfers
1585 I3C Controllers that support this Command Descriptor format shall automatically support Managed CCC
1586 Framing for all Transfer Commands.
1587 • Transition from Private Read/Write to CCC: If this Command Descriptor indicated a Private
1588 Read/Write transfer, and the next Command Descriptor indicates a CCC, the I3C Controller shall start the
1589 CCC framing automatically, as defined in Section 6.3.4.
1590 • The I3C Controller shall detect whether the next Command Descriptor is a CCC based on the value of
1591 fields MODE, CP and CMD.
1592 • Transition from CCC to Private Read/Write: If this Command Descriptor indicated a CCC, and the next
1593 Command Descriptor indicates a Private Read/Write transfer, the I3C Controller shall end the CCC
1594 framing automatically, in an appropriate manner for the End of CCC Command (as defined in the I3C
1595 Specification at Section 5.1.9.2.1 [MIPI02]).
1596 • If this Command Descriptor was a Direct CCC, then the I3C Controller shall drive a Repeated START,
1597 followed by the Broadcast Address (i.e., 7’h7E), followed by another Repeated START to exit the
1598 Direct CCC framing in SDR Mode.
1599 For all Transfer Commands that are CCCs, the Application should ensure that any DAT entries that are
1600 provided in the DEV_INDEX fields for such a sequence do indicate that the Target devices are I3C Devices.
1601 Note:
1602 The specific method of indicating whether a DAT entry describes an I3C Device versus a Legacy I2C
1603 Device shall be defined by the Application. Legacy I2C Target Devices do not support CCCs. Sending
1604 CCCs to Legacy I2C Target Devices is not recommended.
52 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

| Version 1.0  |     |     | Specification for I3C TCRI  |     |     |
| ------------ | --- | --- | --------------------------- | --- | --- |
24-May-2022
7.1.2  Command Descriptor
1605  The write-only Command Descriptor structure defines a transaction, including its parameters, and is sent by
1606  the Application to schedule a command to a Target Device on the I3C Bus while the I3C Controller is
operating in Active Controller mode.
1607
1608  The Command Descriptor is 64 bits (2 DWORDs) in length, and supports a number of common transfer types
1609  (see Section 6.2).
1610  All I3C Transfer Commands can be grouped into the supported Command Types shown in Table 6. This
1611  Specification defines a Command Descriptor structure for each listed Command Type, at the indicated
1612  Section. Table 6 also shows the value of the CMD_ATTR field, for each listed Command Type.
Table 6 Supported Command Types for Command Descriptor, Format 1
1613
| Code                                | Command Type  | Support   | CMD_ATTR  | Section  |     |
| ----------------------------------- | ------------- | --------- | --------- | -------- | --- |
| I  Immediate Data Transfer Command  |               | Required  | 0x1       | 7.1.2.1  |     |
| R  Regular Transfer Command         |               | Required  | 0x0       | 7.1.2.2  |     |
| C  Combo Transfer Command           |               | Optional  | 0x3       | 7.1.2.3  |     |
| M  Internal Control Command         |               | N/A       | 0x7       | N/A      |     |
| A  Address Assignment Command       |               | N/A       | 0x2       | N/A      |     |

1614  Figure 11 provides a high-level overview of the Command Types supported by the Command Descriptor for
1615  all supported I3C Commands, showing one row per Command Type. For the defined Command Types, field
DEV_INDEX holds an index to a specific DAT entry for all transfer operations.
1616
• Field DEV_INDEX is defined for all transfer Commands that use DAT entries for the Dynamic Address of
1617
1618  the indicated Target Device. If Group Addresses are supported, then a DAT entry shall also be used for
1619  each such Group Address.

|     | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     | 53  |
| --- | ------------------------------------- | --- | --- | --- | --- |
  Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
54 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition
D
D
D
W
D
W
D
W
D
B its
O R
W O
B its
O R
W O
B its
O R
W O
in D W O
D 1 (N +
R D 0 (N
in D W O
D 1 (N +
R D 0 (N
in D W O
D 1 (N +
R D 0 (N
R
3
+
R
3
+
R
3
+
D
2
0
D
2
0
D
2
0
)
)
)
)
)
)
F
3
F
3
F
3
ie
1
ie
1
ie
1
ld s
3 0
ld s
3 0
ld s
3 0
f o
f o
f o
r I m
2 9
D A
r R
2 9
r C
2 9
T
e
o
m e d ia
2 8 2 7
A _ B Y T
M O D
g u la r
2 8 2 7
M O D
m b o T
2 8 2 7
M O D
te D a ta T
2 6 2 5
E _ 4
E
T r a n s fe r
2 6 2 5
D A
E
r a n s f e r C
2 6 2 5
D A
E
r a n s fe r C o m
2 4 2 3 2 2
R S D T T
C o m m a n d
2 4 2 3 2 2
T A _ L E N G T H
R S V D
o m m a n d
2 4 2 3 2 2
T A _ L E N G T H
D L P
m
V
a n d
2 1 2
D A T A
D
2 1 2
2 1 2
R
0
_
0
0
B
1
Y
D
1
D
1
D
9
T
E
9
E
9
E
E
V
V
V
1 8
_ 3
_ IN
1 8
_ IN
1 8
_ IN
D
D
D
1
E
1
E
1
E
7
X
7
X
7
X
1
1
1
6
6
6
1
1
1
5
5
5
1
1
1
4
4
4
1 3
D
1 3
1 3
A
R
R
1 2
T A _
1 2
E S E
1 2
E S E
B
R
R
1 1
Y T
C
1 1
V E
C
1 1
V E
C
E
M
D
M
D
M
1 0
_ 2
D
1 0
D
1 0
D
9
9
9
8
8
8
7
7
7
D A
6
T
6
6
O
A
F
_
F
5
B
5
5
S
4 3
Y T E _ 1 o r D
T ID
4 3
D E F _ B Y T E
T ID
4 3
E T o r S U B O
T ID
2
E F _
C M
2
C M
2
F F S
C M
B
D
D
E
D
1
Y
_
1
_
1
T
_
T
A
A
A
E
T
T
T
T
T
T
0
R
0
R
0
R
1620
Figure 11 Overview of Supported Command Types for Command Descriptor, Format 1
1621 Note:
1622 The Transfer Command formats for Format 1 are based on the formats that are defined in version 1.1 of the I3C HCI Specification [MIPI05]. Field
1623 WROC was formerly defined as field ROC in the I3C HCI Specification, but the meaning and intent are the same.

Version 1.0  Specification for I3C TCRI
24-May-2022
7.1.2.1  Immediate Data Transfer Command
1624  This section defines the Command Descriptor structure for Immediate Data Transfer commands.
1625  This structure directly contains data bytes to be transferred, and as a result is only useful for shorter Write-
1626  Type transfers, or CCCs that write data (i.e., write segments for Direct CCCs or Broadcast CCC messages;
1627  see Section 7.1.2.1.1). This structure shall not be used for Read-Type transfers (i.e., to receive data from a
1628  Device).
1629  Note:
1630  Immediate transfers are not CCC-specific, they can describe any transfer. The design intent is to
1631  provide the Application with a method for sending short, immediate transfers in order to reduce the
1632  number of transactions that would otherwise have to be made on internal busses.
| 1633  Table 7 Immediate Data Transfer Command Structure  |                |     |     |
| -------------------------------------------------------- | -------------- | --- | --- |
| Size                                                     | Memory  Reset  |     |     |
Field Name  Description
| [Bits]          | Access  Value  |                                      |     |
| --------------- | -------------- | ------------------------------------ | --- |
| 8  DATA_BYTE_4  | W  0x0         | Immediate Data Transfer Data Byte 4  |     |
[63:56]
Direct argument
| 8  DATA_BYTE_3  | W  0x0  | Immediate Data Transfer Data Byte 3  |     |
| --------------- | ------- | ------------------------------------ | --- |
| [55:48]         |         | Direct argument                      |     |
| 8  DATA_BYTE_2  | W  0x0  | Immediate Data Transfer Data Byte 2  |     |
| [47:40]         |         | Direct argument                      |     |
8  DATA_BYTE_1 /  W  0x0  Immediate Data Transfer Data Byte 1 or DefByte
[39:32]  DEF_BYTE
Direct argument, optionally treated as the Defining Byte
(and thus placed before the Device Address).
1  TOC  W  0x0  Immediate Data Transfer Terminate on Completion
[31]  Controls what Bus condition is issued after completion of the
data transfer.
Values:
•  1’b0: RESTART: Issue Repeated START (Sr) at end of
data transfer
•  1’b1: STOP: Issue Stop (P) at end of data transfer
| 1  WROC  | W  0x0  | Immediate Data Transfer  |     |
| -------- | ------- | ------------------------ | --- |
| [30]     |         | Response on Completion   |     |
Controls whether Response Status is required after
successful completion of the data transfer.
Note:
The Application may change the meaning of this field, or
whether this field is used.
Values:
•  1’b0: NOT_REQUIRED: Response Status is not required
•  1’b1: REQUIRED: Response Status is required
|     | Copyright © 2022 MIPI Alliance, Inc.  |                         | 55  |
| --- | ------------------------------------- | ----------------------- | --- |
|     |                                       | Public Release Edition  |     |

Specification for I3C TCRI Version 1.0
24-May-2022
Size Memory Reset
Field Name Description
[Bits] Access Value
1 RNW W 0x0 Immediate Data Transfer
[29] Direction (RnW)
Identifies direction of the transfer.
This field shall always be set to 1’b0, because Immediate
transfers are valid for Write transactions only.
Values:
• 1’b0: WRITE: Write transfer
• 1’b1: Reserved, do not use
3 MODE W 0x0 Immediate Data Transfer
[28:26] Mode and Speed
Sets the Mode and speed for the I3C or I2C transfer.
Interpretation of this field depends on whether the Device is
in I3C Mode vs. I2C Mode (per the DAT Table entry indexed
by field DEV_INDEX).
Values for I3C Mode:
• 0x0: I3C SDR0
Standard SDR Speed, fSCL Max (up to 12.5 Mhz)
• 0x1–0x4: I3C SDR1–SDR4
Reduced data rates (see Section 7.1.1)
• 0x5: I3C HDR-TSx
HDR-Ternary Mode
• 0x6: I3C HDR-DDR
HDR Double Data Rate Mode
• 0x7: Reserved
Values for I2C Mode:
• 0x0–0x4: I2C at supported data rates
(see Section 7.1.1)
• 0x5–0x7: Reserved
3 DTT W 0x0 Immediate Data Transfer
[25:23] Type and Byte Count
Number of valid data bytes to use in this Immediate Data
Transfer Descriptor.
Values 5-7 indicate that the first Data Byte shall be treated
as the Defining Byte, for CCCs with a Defining Byte.
Note:
This field should be set to a non-zero value, except for
valid transfers with no data bytes that only require an
ACK of a Dynamic Address (such as any Direct CCCs
that do not have any payload defined). Broadcast CCCs
with no subsequent bytes (such as SETAASA) are also
valid examples of zero-byte payloads.
Values:
• 0: No payload
• 1–4: N bytes are valid
• 5: Defining Byte + 0
• 6: Defining Byte + 1
• 7: Defining Byte + 2
2 RESERVED – – –
[22:21]
56 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]        | Access  Value  |                          |     |
| ------------- | -------------- | ------------------------ | --- |
| 5  DEV_INDEX  | W  0x0         | Immediate Data Transfer  |     |
| [20:16]       |                | Device Index             |     |
Indicates the DAT table index for the Target Device being
addressed with the transfer.
The DAT entry indicated by this field must contain a valid
Dynamic Address, for Read/Write transfers and for Direct
CCCs.
This field is ignored for Broadcast CCCs.
| 1  CP  | W  0x0  | Immediate Data Transfer  |     |
| ------ | ------- | ------------------------ | --- |
| [15]   |         | Command Present          |     |
Indicates whether field CMD is valid for a CCC or HDR
Transfer.
Values:
•  1’b0: TRANSFER: This structure describes an SDR
transfer, so the CMD field is not valid.
•  1’b1: CCC_HDR: This structure describes a CCC or HDR
transfer, so field CMD is valid.
| 8  CMD  | W  0x0  | Immediate Data Transfer       |     |
| ------- | ------- | ----------------------------- | --- |
| [14:7]  |         | CCC / HDR Command Code Value  |     |
Specifies the I3C Command code. The interpretation of this
field depends on field CP.
For CCC: 8 bits (i.e., the Command Code, see Section 6.3)
For HDR: 7 bits (i.e., bits 13:7 are used for the lower 7 bits
of the HDR-DDR or HDR-TSx Command Code, and the
upper bit is determined by bit 29; bit 14 is ignored).
| 4  TID  | W  0x0  | Immediate Data Transfer  |     |
| ------- | ------- | ------------------------ | --- |
| [6:3]   |         | Transaction ID           |     |
Used as an identification tag for this command.
This field shall be populated by the Application, and the
same value shall be reflected in the Response Descriptor.
| 3  CMD_ATTR  | W  0x0  | Immediate Data Transfer  |     |
| ------------ | ------- | ------------------------ | --- |
| [2:0]        |         | Command Attribute        |     |
Command Type, defining the format of the other fields.
Values:
•  0x1: IMMED_DATA_XFER: Immediate Data Transfer
•  All other values are defined for other Command Types, or
reserved for future use.

|     | Copyright © 2022 MIPI Alliance, Inc.  |                         | 57  |
| --- | ------------------------------------- | ----------------------- | --- |
|     |                                       | Public Release Edition  |     |

| Specification for I3C TCRI  |     |     |     |     | Version 1.0  |
| --------------------------- | --- | --- | --- | --- | ------------ |
|                             |     |     |     |     | 24-May-2022  |
7.1.2.1.1  Usage for CCCs with Managed CCC Framing
1634  An Immediate Data Transfer command that is used for a CCC with Managed CCC Framing (per Section 6.3)
1635  shall have field CP set to 1’b1, and field MODE set to any valid value that indicates a transfer in SDR Mode.
1636  The Application shall provide the I3C Common Command Code in field CMD. If the Transfer Command
1637  indicates that the CCC is sent with a Defining Byte, then the Application shall also set field DTT appropriately,
1638  per Table 8. For Direct Write or Direct SET CCCs, field DTT shall also indicate the length of the data payload
that is sent to the addressed I3C Target Address or Group Address, as part of Direct CCC framing (per
1639
1640  Section 6.3).
1641  • If the CCC is sent with a Defining Byte, then bits 39:22 (i.e., field DEF_BYTE) indicates the Defining
1642  Byte value, and subsequent fields (i.e., fields DATA_BYTE_2 and DATA_BYTE_3) may be used for
optional first and second bytes (respectively) of the data payload.
1643
1644  • If the CCC is sent without a Defining byte, then bits 39:22 (i.e., field DATA_BYTE_1) may be used for
1645  the first byte of the optional data payload; and subsequent fields (i.e., DATA_BYTE_2, DATA_BYTE_3
and DATA_BYTE_4) may be used for optional second, third and fourth bytes (respectively) of the data
1646
1647  payload.
1648  This Transfer Command type may also be used for a Broadcast CCC. In this case, the Application shall set
1649  field DEV_INDEX to zero, since the I3C Controller ignores this field for Broadcast CCCs.
1650  Table 8 Immediate Data Transfer Command Usage for CCCs and Defining Bytes
CCC Sent
| Field DTT  |     | First Byte  | Second Byte  | Third Byte  | Fourth Byte  |
| ---------- | --- | ----------- | ------------ | ----------- | ------------ |
with Defining
| Value  |     | is in Field  | is in Field  | is in Field  | is in Field  |
| ------ | --- | ------------ | ------------ | ------------ | ------------ |
Byte?
| 0   |      | –            | –            | –            | –            |
| --- | ---- | ------------ | ------------ | ------------ | ------------ |
| 1   |      | DATA_BYTE_1  | –            | –            | –            |
| 2   | No   | DATA_BYTE_1  | DATA_BYTE_2  | –            | –            |
| 3   |      | DATA_BYTE_1  | DATA_BYTE_2  | DATA_BYTE_3  | –            |
| 4   |      | DATA_BYTE_1  | DATA_BYTE_2  | DATA_BYTE_3  | DATA_BYTE_4  |
| 5   |      | –            | –            | –            | –            |
| 6   | Yes  | DATA_BYTE_2  | –            | –            | –            |
| 7   |      | DATA_BYTE_2  | DATA_BYTE_3  | –            | –            |

1651  Note:
1652  An Immediate Data Transfer command that indicates a CCC with a Defining Byte does not support
1653  more than two data bytes for the data payload. In order to send a CCC with a Defining Byte and more
than two data bytes for the data payload, the Application must use the Regular Data Transfer
1654
1655  command (see Section 7.1.2.2.1).
| 58  |     | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     |
| --- | --- | ------------------------------------- | --- | --- | --- |
|     |     | Public Release Edition                |     |     |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
7.1.2.2  Regular Data Transfer Command
1656  This section defines the Command Descriptor structure for Regular Data Transfer commands. This Transfer
1657  Command  type  may  be  used  for  any  Private  Read  or  Private Write,  as  well  as  many  CCCs  (per
Section 7.1.2.2.1).
1658
1659  The Command Descriptor structure for Regular Data Transfer commands indicates that the transfer should
1660  use a data buffer or queue, based on the operating mode of the Application.
Table 9 Regular Data Transfer Command Structure
1661
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]           | Access  Value  |                |     |
| ---------------- | -------------- | -------------- | --- |
| 16  DATA_LENGTH  | W  0x0         | Data Transfer  |     |
| [63:48]          |                | Data Length    |     |
Indicates the number of bytes to be transferred.
Note:
This field should be set to a non-zero value.
For valid transfers with no data bytes that only
require an ACK of a Dynamic Address (such as
any Direct CCCs that do not have payload
defined), Immediate Data Transfer Commands
should typically be used instead.
| 8  RESERVED  | –  –  | –   |     |
| ------------ | ----- | --- | --- |
[47:40]
Data Transfer
| 8  DEF_BYTE  | W  0x0  |     |     |
| ------------ | ------- | --- | --- |
Defining Byte for Present CCC
[39:32]
Valid if field DBP contains 1’b1
| 1  TOC  | W  0x0  | Data Transfer            |     |
| ------- | ------- | ------------------------ | --- |
| [31]    |         | Terminate on Completion  |     |
Controls what Bus condition will be issued after
completion of the transfer, per Section 6.2.5.
Values:
•  1’b0: RESTART: Issue Repeated START (Sr) at end
of transfer
•  1’b1: STOP: Issue Stop (P) at end of transfer
| 1  WROC  | W  0x0  | Data Transfer           |     |
| -------- | ------- | ----------------------- | --- |
| [30]     |         | Response on Completion  |     |
Controls whether Response Status is required after
successful completion of the data transfer.
Note:
The Application may change the meaning of this
field, or whether this field is used.
Values:
•  1’b0: NOT_REQUIRED: Response Status is not
required
•  1’b1: REQUIRED: Response Status is required
|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 59  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]  | Access  Value  |                  |
| ------- | -------------- | ---------------- |
| 1  RNW  | W  0x0         | Data Transfer    |
| [29]    |                | Direction (RnW)  |
Identifies the direction of this transfer.
Values:
•  1’b0: WRITE: Write transfer
•  1’b1: READ: Read transfer
| 3  MODE  | W  0x0  | Data Transfer   |
| -------- | ------- | --------------- |
| [28:26]  |         | Speed and Mode  |
Sets the Mode and speed for the I3C or I2C transfer.
Interpretation of this field depends on whether the
Device is in I3C Mode vs. I2C Mode (per the DAT Table
entry indexed by field DEV_INDEX).
Values for I3C Mode:
•  0x0: I3C SDR0
Standard SDR Speed, fSCL Max (up to 12.5 MHz)
•  0x1–0x4: I3C SDR1–SDR4
Reduced data rates (see Section 7.1.1)
•  0x5: I3C HDR-TSx
HDR-Ternary Mode
•  0x6: I3C HDR-DDR
HDR Double Data Rate Mode
•  0x7: Reserved
Values for I2C Mode:
•  0x0–0x4: I2C at supported data rates (see
Section 7.1.1)
•  0x5–0x7: Reserved
| 1  DBP  | W  0x0  | Data Transfer                  |
| ------- | ------- | ------------------------------ |
| [25]    |         | Defining Byte for CCC Present  |
If this field contains 1’b1, then field DEF_BYTE contains
the Defining Byte value.
| 1  SHORT_READ_ERR  | W  0x0  | Data Transfer        |
| ------------------ | ------- | -------------------- |
| [24]               |         | Short Read Is Error  |
Controls whether a ‘short’ Read-type transfer is
permitted or treated as an error.
Note:
This field is valid for I3C Read-type transfers only.
For I3C Write-type transfers or I2C transfers, the
Application shall always set this field to 1’b0.
Values (for I3C Read transfers):
•  1’b0: ALLOW_SHORT_READ: All successful Read
transfers are permitted, for lengths up to and
including field DATA_LENGTH.
•  1’b1: SHORT_READ_IS_ERROR: Only allowed if field
RNW is set to 1’b1. A ‘short’ Read transfer is not
permitted, and will be treated as a transfer error. If
the indicated Target Device does not return the
number of bytes requested via field DATA_LENGTH,
then this Read transfer shall be treated as an error
and the I3C Controller shall halt after the end of the
Read-type transfer (see Section 6.2.1).
| 60  | Copyright © 2022 MIPI Alliance, Inc.  |     |
| --- | ------------------------------------- | --- |
|     | Public Release Edition                |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]       | Access  Value  |     |     |
| ------------ | -------------- | --- | --- |
| 3  RESERVED  | –  –           | –   |     |
[23:21]
| 5  DEV_INDEX  | W  0x0  | Data Transfer  |     |
| ------------- | ------- | -------------- | --- |
| [20:16]       |         | Device Index   |     |
Contains the DAT table index for the Target Device
being addressed with the transfer.
The DAT entry indicated by this field must contain a
valid Dynamic Address, for Read/Write transfers and
for Direct CCCs.
This field is ignored for Broadcast CCCs.
| 1  CP  | W  0x0  | Data Transfer    |     |
| ------ | ------- | ---------------- | --- |
| [15]   |         | Command Present  |     |
Indicates whether field CMD is valid for a CCC or HDR
Transfer.
Values:
•  1’b0: TRANSFER: This structure describes an SDR
transfer, so the CMD field is not valid.
•  1’b1: CCC_HDR: This structure describes a CCC or
HDR transfer, so field CMD is valid.
| 8  CMD  | W  0x0  | Data Transfer                 |     |
| ------- | ------- | ----------------------------- | --- |
| [14:7]  |         | CCC / HDR Command Code Value  |     |
Specifies the I3C Command code. The interpretation
of this field depends on field CP.
•  For CCC: 8 bits (i.e., the Command Code; see
Section 6.3)
•  For HDR: 7 bits (i.e., bits 13:7 are used for the
lower 7 bits of the HDR-DDR or HDR-TSx
Command Code, and the upper bit is determined by
bit 29; bit 14 is ignored).
| 4  TID  | W  0x0  | Data Transfer   |     |
| ------- | ------- | --------------- | --- |
| [6:3]   |         | Transaction ID  |     |
Identification tag for this command.
| 3  CMD_ATTR  | W  0x0  | Data Transfer      |     |
| ------------ | ------- | ------------------ | --- |
| [2:0]        |         | Command Attribute  |     |
Command Type, defining the format of the other fields.
Values:
•  0x0: XFER: Regular Transfer
•  All other values are defined for other Command
Types, or reserved for future use.

|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 61  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI Version 1.0
24-May-2022
7.1.2.2.1 Usage for CCCs with Managed CCC Framing
1662 A Regular Data Transfer command that is used for a CCC with Managed CCC Framing (per Section 6.3)
1663 shall have field CP set to 1’b1, and field MODE set to any valid value that indicates a transfer in SDR Mode.
1664 The Application shall provide the I3C Common Command Code in field CMD. If the Transfer Command
1665 indicates that the CCC is sent with a Defining Byte, then the Application shall also set field DBP to 1’b1 and
1666 provide the Defining Byte value in field DEF_BYTE. However, if the CCC is sent without a Defining Byte,
1667 then the Application shall set field DBP to 1’b0, and the value of field DEF_BYTE shall be ignored.
1668 This Transfer Command type may be used for Broadcast CCC messages, or for any type of Direct CCC
1669 segments (i.e., a single segment per Transfer Command):
1670 • For a Broadcast CCC message or a single Write segment of a Direct CCC (i.e., Direct Write or Direct
1671 SET), the Application shall set field RNW to indicate a Write-Type transfer, and shall provide the write
1672 data to the appropriate Queue/Buffer, per the operating mode.
1673 • For a single Read segment of a Direct CCC (i.e., Direct Read or Direct GET), the Application shall set
1674 field RNW to indicate a Read-Type transfer, and the data returned from the indicated I3C Target Device
1675 shall be read from the appropriate Queue/Buffer, per the operating mode.
1676 • Additionally, for a Broadcast CCC message, the Application shall set field DEV_INDEX to zero, since the
1677 I3C Controller ignores this field for Broadcast CCCs.
7.1.2.3 Combo Transfer (Write + Write/Read) Command
1678 This section defines the Command Descriptor structure for Combo Transfer commands.
1679 Each Combo Transfer Command Descriptor describes a combined Write + Read/Write operation. These two
1680 phases of the Combo Transfer shall be separated by an appropriate condition that restarts the framing:
1681 • For both phases in SDR Mode: Repeated START.
1682 • For the first phase in SDR Mode and the second phase in an HDR Mode: Repeated START, followed
1683 by the CCC to enter the appropriate HDR Mode (i.e., using the ENTHDR0–ENTHDR7 CCCs, as defined
1684 in version 1.1.1 of the I3C Specification [MIPI02] at Section 5.1.9.3.9).
1685 • For both phases in HDR Mode: The HDR Restart Pattern.
1686 The Combo Transfer Command Descriptor varies in format, depending on the particular transfer operation
1687 being requested on the I3C Bus:
1688 • SDR:
1689 S + ADR + ACK + Offset + Sr + ADR + Data + P
1690 • HDR (16_BIT_SUBOFFSET == 1, Length first):
1691 S + WrCmd + ADR + Length (16 bits) + Offset (16 bits) + Sr + CMD + ADR + Data + P
1692 • HDR (16_BIT_SUBOFFSET == 1, Length second):
1693 S + WrCmd + ADR + Offset (16 bits) + Length (16 bits) + Sr + CMD + ADR + Data + P
1694 • HDR (16_BIT_SUBOFFSET == 1, no Length):
1695 S + WrCmd + ADR + Offset (16 bits) + Sr + CMD + ADR + Data + P
1696 • HDR (16_BIT_SUBOFFSET == 0, Length first):
1697 S + WrCmd + ADR + Length (8 bits) and Offset (8 bits) + Sr + CMD + ADR + Data + P
1698 • HDR (16_BIT_SUBOFFSET == 0, Length second):
1699 S + WrCmd + ADR + Offset (8 bits) and Length (8 bits) + Sr + CMD + ADR + Data + P
1700 • HDR (16_BIT_SUBOFFSET == 0, no Length):
1701 S + WrCmd + ADR + All 0s padding (8 bits) and Offset (8 bits) + Sr + CMD + ADR + Data + P
1702 For Combo Transfers where the first phase is in an HDR Mode, the value of WrCMD is derived from the
1703 provided value of the 8-bit CMD field in the Command Descriptor. The I3C Controller shall mask off the high
1704 bit from the CMD field:
1705 WrCmd = CMD & 0x7F
62 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

| Version 1.0  |     |     |     |     |     |     |     |     |     | Specification for I3C TCRI  |     |     |
| ------------ | --- | --- | --- | --- | --- | --- | --- | --- | --- | --------------------------- | --- | --- |
24-May-2022
1706  Note:
1707  Per the I3C Specification [MIPI02], the command codes for Write are 0x00–0x7F, and for Read the
1708  command codes are 0x80–0xFF.
1709  If the FIRST_PHASE_MODE field is set to 0, then the first write on the I3C Bus is executed in SDR Mode
1710  (i.e., SDR0), and the speed and Mode of the second phase are determined by the MODE field.
|     | Command Descriptor Structure Lo |     |     | Command  |     |     |     |     |     |     |     |     |
| --- | ------------------------------- | --- | --- | -------- | --- | --- | --- | --- | --- | --- | --- | --- |
Descriptor
Command Descriptor Structure Hi
|     | BLP=0 IOC               | Block Size |     |                      |     |     |     |                    |     |     |     |     |
| --- | ----------------------- | ---------- | --- | -------------------- | --- | --- | --- | ------------------ | --- | --- | --- | --- |
|     | Data Buffer List Ptr Lo |            |     | Pointer to physical  |     |     |     |                    |     |     |     |     |
|     |                         |            |     | memory or Scatter    |     |     |     | Protocol specific  |     |     |     |     |
|     |                         |            |     | Gather list          |     |     |     | (hardcoded)        |     |     |     |     |
Data Buffer List Ptr Hi
Specified by Combo
|     | a) SDR+SDR |     |     |     |     |     |     | Command Descriptor |     |     |     |     |
| --- | ---------- | --- | --- | --- | --- | --- | --- | ------------------ | --- | --- | --- | --- |
Specified by Transfer
|     | First phase (SDR) |        |        | Second phase (SDR) |     |     |     |                     | Descriptor |     |     |     |
| --- | ----------------- | ------ | ------ | ------------------ | --- | --- | --- | ------------------- | ---------- | --- | --- | --- |
|     | S                 |        |        |                    | P   |     |     | Derived from Combo  |            |     |     |     |
|     | Sr ADR            | OFFSET | Sr ADR | DATA               | Sr  |     |     | Command Descriptor  |            |     |     |     |
b) SDR+HDR
|     | First phase (SDR) |     |     |     | Second phase (HDR) |     |     |     |     |     |     |     |
| --- | ----------------- | --- | --- | --- | ------------------ | --- | --- | --- | --- | --- | --- | --- |
Command Word
|     | S   |        | ENTHDR  | Code for       |     |     |      | P   |     |     |     |     |
| --- | --- | ------ | ------- | -------------- | --- | --- | ---- | --- | --- | --- | --- | --- |
|     | ADR | OFFSET | Sr      |                |     | ADR | DATA | CRC |     |     |     |     |
|     | Sr  |        |         | CCC Write/Read |     |     |      | Sr  |     |     |     |     |
c) HDR+HDR (8-bit Offset, Length first)
|     |           |           | First phase (HDR) |                          |        |     |              | Second phase (HDR) |      |     |     |     |
| --- | --------- | --------- | ----------------- | ------------------------ | ------ | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|     |           |           | Command Word      | Data (Length and Offset) |        |     | Command Word |                    | Data |     |     |     |
|     | S ENTHDR  | Code for  |                   |                          |        | HDR | Code for     |                    |      |     | P   |     |
|     | Sr CCC    | Write     | ADR               | Length                   | Offset | Sr  | Write/Read   | ADR                | DATA | CRC | Sr  |     |
d) HDR+HDR (8-bit Offset, Length second)
|     |           |           | First phase (HDR) |                          |        |     |              | Second phase (HDR) |      |     |     |     |
| --- | --------- | --------- | ----------------- | ------------------------ | ------ | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|     |           |           | Command Word      | Data (Length and Offset) |        |     | Command Word |                    | Data |     |     |     |
|     | S ENTHDR  | Code for  |                   |                          |        | HDR | Code for     |                    |      |     | P   |     |
|     |           |           | ADR               | Offset                   | Length |     |              | ADR                | DATA | CRC |     |     |
|     | Sr CCC    | Write     |                   |                          |        | Sr  | Write/Read   |                    |      |     | Sr  |     |
e) HDR+HDR (8-bit Offset, no Length)
|     |           |           | First phase (HDR) |                          |        |     |              | Second phase (HDR) |      |     |     |     |
| --- | --------- | --------- | ----------------- | ------------------------ | ------ | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|     |           |           | Command Word      | Data (Length and Offset) |        |     | Command Word |                    | Data |     |     |     |
|     | S ENTHDR  | Code for  |                   |                          |        | HDR | Code for     |                    |      |     | P   |     |
|     | Sr CCC    | Write     | ADR               | all 0s                   | Offset | Sr  | Write/Read   | ADR                | DATA | CRC | Sr  |     |
f) HDR+HDR (16-bit Offset, Length first)
|     |           |           | First phase (HDR) |                          |     |                          |     |     |              | Second phase (HDR) |      |     |
| --- | --------- | --------- | ----------------- | ------------------------ | --- | ------------------------ | --- | --- | ------------ | ------------------ | ---- | --- |
|     |           |           | Command Word      | Data (Length and Offset) |     | Data (Length and Offset) |     |     | Command Word |                    | Data |     |
|     | S ENTHDR  | Code for  |                   |                          |     |                          |     | HDR | Code for     |                    |      | P   |
Sr CCC Write ADR Length Length Offset Offset Sr Write/Read ADR DATA CRC Sr
g) HDR+HDR (16-bit Offset, Length second)
|     |           |           | First phase (HDR) |                          |     |                          |     |     |              | Second phase (HDR) |      |     |
| --- | --------- | --------- | ----------------- | ------------------------ | --- | ------------------------ | --- | --- | ------------ | ------------------ | ---- | --- |
|     |           |           | Command Word      | Data (Length and Offset) |     | Data (Length and Offset) |     |     | Command Word |                    | Data |     |
|     | S ENTHDR  | Code for  |                   |                          |     |                          |     | HDR | Code for     |                    |      | P   |
Sr CCC Write ADR Offset Offset Length Length Sr Write/Read ADR DATA CRC Sr
h) HDR+HDR (16-bit Offset, no Length)
|     |     |     | First phase (HDR) |                          |     |     |              | Second phase (HDR) |      |     |     |     |
| --- | --- | --- | ----------------- | ------------------------ | --- | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|     |     |     | Command Word      | Data (Length and Offset) |     |     | Command Word |                    | Data |     |     |     |
S ENTHDR  Code for  ADR Offset Offset HDR Code for  ADR DATA CRC P
|     | Sr CCC | Write |     |     |     | Sr  | Write/Read |     |     |     | Sr  |     |
| --- | ------ | ----- | --- | --- | --- | --- | ---------- | --- | --- | --- | --- | --- |
1711
Figure 12 I3C Bus Activity for Combo Transfer
|     |     |     |     | Copyright © 2022 MIPI Alliance, Inc.  |                         |     |     |     |     |     |     | 63  |
| --- | --- | --- | --- | ------------------------------------- | ----------------------- | --- | --- | --- | --- | --- | --- | --- |
|     |     |     |     |                                       | Public Release Edition  |     |     |     |     |     |     |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
In the case of a Combo Transfer Command failure due to a NACK or a transfer that was aborted early, the
1712
1713  returned status in the Response Descriptor shall indicate the phase of the transaction in which the failure
1714  actually occurred. The Application shall accommodate this returned status in its error handling flow.
1715  • For errors in the first phase of a Combo transfer:
1716  • If the indicated Target Device NACKs the Write, then the I3C Controller shall return an error code 0x5
1717  (NACK) in field ERR_STATUS.
1718  • If the transfer is aborted early, then the I3C Controller shall return an error code 0x9 (BUS_ABORTED)
1719  in field ERR_STATUS.
1720  • For errors in the second phase of a Combo transfer:
1721  • If the indicated Target Device NACKs the Write or Read as part of the second phase, then the I3C
1722  Controller shall return an error code 0xC (Transfer Type Specific: COMBO_NACK_2ND) in field
1723  ERR_STATUS.
1724  • If the second phase of the transfer is aborted early, then the I3C Controller shall return an error code
1725  0xD (Transfer Type Specific: COMBO_BUS_ABORTED_2ND) in field ERR_STATUS.
• These error codes are defined in Section 6.4.1.
1726
1727  Table 10 Combo (Write + Write/Read) Transfer Command Structure
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]           | Access  Value  |                 |
| ---------------- | -------------- | --------------- |
| 16  DATA_LENGTH  | W  0x0         | Combo Transfer  |
| [63:48]          |                | Data Length     |
Number of bytes to be transferred.
Note:
This field must be set to non-zero value.
| 16  OFFSET / SUBOFFSET  | –  –  | Combo Transfer       |
| ----------------------- | ----- | -------------------- |
| [47:32]                 |       | Offset / Sub-Offset  |
Offset of the target operation
| 1  TOC  | W  0x0  | Combo Transfer  |
| ------- | ------- | --------------- |
Terminate on Completion
[31]
Controls what Bus condition is issued after
completion of the transfer.
Values:
•  1’b0: RESTART: Issue Repeated START (Sr)
at end of transfer
•  1’b1: STOP: Issue Stop (P) at end of transfer
| 1  WROC  | W  0x0  | Combo Transfer          |
| -------- | ------- | ----------------------- |
| [30]     |         | Response on Completion  |
Controls whether Response Status is required
after successful completion of the Combo
transfer.
Note:
The Application may change the meaning of
this field, or whether this field is used.
Values:
•  1’b0: NOT_REQUIRED: Response Status is not
required
•  1’b1: REQUIRED: Response Status is required
| 64  Copyright © 2022 MIPI Alliance, Inc.  |                         |     |
| ----------------------------------------- | ----------------------- | --- |
|                                           | Public Release Edition  |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]  | Access  Value  |                  |     |
| ------- | -------------- | ---------------- | --- |
| 1  RNW  | W  0x0         | Combo Transfer   |     |
| [29]    |                | Direction (RnW)  |     |
Sets transfer direction. This applies only to the
second phase; the first phase is always a Write
transfer.
Values:
•  1’b0: WRITE: Second phase is a Write transfer
•  1’b1: READ: Second phase is a Read transfer.
The Combo Transfer Command does not
support ‘short’ Read transfers (see
Section 6.2.1).
| 3  MODE  | W  0x0  | Combo Transfer  |     |
| -------- | ------- | --------------- | --- |
| [28:26]  |         | Speed and Mode  |     |
Sets the Mode and speed for the I3C or I2C
transfer.
Interpretation of this field depends on whether
the Device is in I3C Mode vs. I2C Mode (per the
DAT Table entry indexed by field DEV_INDEX).
Values for I3C Mode:
•  0x0: I3C SDR0
Standard SDR Speed, fSCL Max (up to 12.5
MHz)
•  0x1–0x4: I3C SDR1–SDR4
Reduced data rates (see Section 7.1.1)
•  0x5: I3C HDR-TSx
HDR-Ternary Mode
•  0x6: I3C HDR-DDR
HDR Double Data Rate Mode
•  0x7: Reserved
Values for I2C Mode:
•  0x0–0x4: I2C at supported data rates (see
Section 7.1.1)
•  0x5–0x7: Reserved
| 1  16_BIT_SUBOFFSET  | W  0x0  | Combo Transfer   |     |
| -------------------- | ------- | ---------------- | --- |
| [25]                 |         | Sub Offset Size  |     |
Sets Sub-Offset length to 8 or 16 bits.
Values:
•  1’b0: 8_BIT_SUBOFFSET: Sub-offset is 8 bits
long. Value is encoded in Lower Byte of the
OFFSET / SUBOFFSET field.
•  1’b1: 16_BIT_SUBOFFSET: Sub-offset is 16 bits
long
|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 65  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]               | Access  Value  |                   |
| -------------------- | -------------- | ----------------- |
| 1  FIRST_PHASE_MODE  | W  0x0         | Combo Transfer    |
| [24]                 |                | First Phase Mode  |
Indicates whether the first phase of the Combo
Transfer is executed in SDR Mode, vs. the Mode
indicated by the MODE field.
Values:
•  1’b0: SDR: First phase is executed in SDR
Mode
•  1’b1: MODE: First phase is executed in the
Mode indicated by the MODE field
| 2  DATA_LENGTH_POSITION  | W  0x0  | Data Length Field Position                      |
| ------------------------ | ------- | ----------------------------------------------- |
| [23:22]                  |         | Indicates whether and where to put Data Length  |
(DATA_LENGTH) in the first phase of the transfer.
This field is only applicable if First phase of the
transfer is executed in HDR Mode.
Whether 8 bits vs. 16 bits of the Data Length field
is used is indicated with field
16_BIT_SUBOFFSET. In the case of 8 bits, it is
encoded in Lower Byte of field DATA_LENGTH.
Values:
•  2’b0: NO: Do not put Length field
•  2’b1: FIRST: Put Length as first field
•  2’b2: SECOND: Put Length as second field
•  2’b3: RESERVED: Don’t use
| 1  RESERVED  | –  –  | –   |
| ------------ | ----- | --- |
[21]
| 5  DEV_INDEX  | W  0x0  | Combo Transfer  |
| ------------- | ------- | --------------- |
| [20:16]       |         | Device Index    |
Contains the DAT table index for the Target
Device being addressed with the transfer.
The DAT entry indicated by this field must contain
a valid Dynamic Address.
| 1  CP  | W  0x0  | Combo Transfer   |
| ------ | ------- | ---------------- |
| [15]   |         | Command Present  |
Indicates whether the CMD field is valid for a
HDR Transfer. This field must be set to 1’b1 for a
Combo transfer.
Values:
•  1’b0: Invalid value for a Combo Transfer.
•  1’b1: If this is an HDR transfer, then field CMD
is valid.
| 66  Copyright © 2022 MIPI Alliance, Inc.  |                         |     |
| ----------------------------------------- | ----------------------- | --- |
|                                           | Public Release Edition  |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]  | Access  Value  |                         |     |
| ------- | -------------- | ----------------------- | --- |
| 8  CMD  | W  0x0         | Combo Transfer          |     |
| [14:7]  |                | HDR Command Code Value  |     |
•  For HDR: Contains the lower 7 bits of the
HDR-DDR or HDR-TSx Command code (i.e.,
bits 13:7 are used, and bit 14 is ignored). The
I3C Controller shall automatically use the
correct upper bit for the second phase, as
determined by bit 29.
•  For SDR: This field is reserved, and shall be
set to zero.
| 4  TID  | W  0x0  | Combo Transfer  |     |
| ------- | ------- | --------------- | --- |
| [6:3]   |         | Transaction ID  |     |
Identification tag for the command.
| 3  CMD_ATTR  | W  0x0  | Combo Transfer     |     |
| ------------ | ------- | ------------------ | --- |
| [2:0]        |         | Command Attribute  |     |
Command Type, defining the format of the other
fields.
Values:
•  0x3: WWR_COMBO_XFER: Write + Write/Read
Combo Transfer
•  All other values are defined for other
Command Types, or reserved for future use.

7.1.2.4  Internal Control Command
1728  Applications can also define specific Internal Control Commands that can be used for any purpose, including
configuring the I3C Controller or other functional logic. Internal Control Commands can be enqueued on
1729
1730  their own, or framed with other Transfer Commands as modifiers or qualifiers to how the I3C Controller or
1731  other functional logic processes transactions, initiates other actions or methods on the I3C Bus.
An Internal Control Command shares the same general format, with field CMD_ATTR set to 0x7. The
1732
1733  remaining fields in the Command Descriptor are available for the Application to define for other purposes,
1734  and are not defined in this Specification.
7.1.2.5  Address Assignment Command
1735  Applications can also define specific Address Assignment Commands that are used for the special task of
1736  Dynamic Address Assignment using any of its supported methods. Address Assignment Commands can be
1737  enqueued on their own, or in sequences. In most cases, Address Assignment Commands should not be
intermixed with other Transfer Commands.
1738
1739  An Address Assignment Command shares the same general format, with field CMD_ATTR set to 0x2. The
1740  remaining fields in the Command Descriptor are available for the Application to define for other purposes,
and are not defined in this Specification.
1741
|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 67  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI Version 1.0
24-May-2022
7.1.3 Response Descriptor
1742 The Response Descriptor is a read-only structure describing the success or failure of a Transfer Command,
1743 and the amount of data transferred.
1744 The Response Descriptor is 32 bits (i.e., 1 DWORD) in length.
1745 Table 11 Response Descriptor Structure
Size Memory Reset
Field Name Description
[Bits] Access Value
4 ERR_STATUS R 0x0 Response Error Status
[31:28] Indicates the Response status for the processed
command (i.e., either success or the error type
encountered).
Error codes are described in Section 6.4.1.
Values:
• 0x0: SUCCESS: Transfer successful, no error.
• 0x1: CRC: CRC Error
• 0x2: PARITY: Parity Error
• 0x3: FRAME: Frame Error
• 0x4: ADDR_HEADER: Address Header Error
• 0x5: NACK: Address NACK’ed or Dynamic Address
Assignment NACK’ed
• 0x6: OVL: Receive Overflow or Transfer Underflow
Error
• 0x7: I3C_SHORT_READ_ERR: Target returned fewer
data bytes than requested in field DATA_LENGTH of a
Transfer Command that did not permit a ‘short’ read
(per Section 6.2.1 and Section 7.1.2.2)
• 0x8: HC_ABORTED: Aborted (i.e., terminated) by I3C
Controller due to internal error
• 0x9: Transfer terminated due to Bus action:
• For I2C: I2C_WR_DATA_NACK:
Aborted due to NACK received during an I2C Write
Data transfer
• For I3C: BUS_ABORTED:
Aborted due to Early Termination, or Target not
completing read or write of data phase of transfer
• 0xA: NOT_SUPPORTED: Command with specific
parameters not supported by the I3C Controller
implementation (e.g., specific Internal Control codes
may not be supported)
• 0xB: RESERVED
• 0xC–0xF: Transfer Type Specific Errors, defined for
specific transfer types
4 TID R 0x0 Command/Response Transaction ID
[27:24] Identification tag for the command.
This value shall match the value of field TID, for a
previously enqueued Command Descriptor that was sent
on the Bus.
Values:
• 0x0–0xF: Valid Transaction IDs
68 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]       | Access  Value  |     |     |
| ------------ | -------------- | --- | --- |
| 8  RESERVED  | –  –           | –   |     |
[23:16]
| 16  DATA_LENGTH  | R  0x0  | Data Length / Device Count                         |     |
| ---------------- | ------- | -------------------------------------------------- | --- |
| [15:0]           |         | The meaning of this field depends on the context:  |     |
For Write Transfer: Remaining data length (in bytes)
For Read Transfer: Received data length (in bytes)
For Internal Control or Address Assignment:
Application may use for any purpose

|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 69  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI Version 1.0
24-May-2022
7.2 Format 2: Legacy Format, Direct Addressed
1746 The size of this Command Descriptor format is 2 DWORDs. This Command Descriptor format is derived
1747 from Format 1 (i.e., the format that was defined in version 1.1 of the I3C HCI Specification [MIPI05]) and
1748 enables selected new features that were added in version 1.1+ of the I3C Specification [MIPI06].
1749 The Command Descriptor is defined in Section 7.2.2 and supports several types of Transfer Commands, as
1750 well as the Internal Control type command, as indicated by the CMD_ATTR field. Transfers are limited to 64
1751 KB in size. For all Transfer Commands, the Command Descriptor includes a 7-bit DEV_ADDRESS field that
1752 directly addresses the Target:
1753 • For private transfers and Direct CCCs: The I3C Controller directly uses the Target Address provided in
1754 the DEV_ADDRESS field. The Application shall provide a valid Dynamic Address of a Device on the I3C
1755 Bus (or an assigned Group Address for Write-type transfers, if supported).
1756 • For Broadcast CCCs: The I3C Controller shall not use the DEV_ADDRESS field. The Application should
1757 set DEV_ADDRESS to 7’h00.
1758 Note:
1759 The Application may also choose to provide a DAT that allows for configuration of some or all Targets.
1760 However, the DAT entry is not used in this Command Descriptor format.
1761 This Command Descriptor format does not support transfers using some of the new features enabled
1762 by version 1.1+ of the I3C Specification [MIPI06], such as HDR-BT (Bulk Transfer) Mode, Multi-Lane
1763 transfers in any supported I3C Modes, CCC flows in HDR Modes, or several types of Combo
1764 transfers that are necessary for specific use cases such as Device to Device Tunneling. A future
1765 version of this I3C TCRI Specification is expected to enable such features.
7.2.1 Common Aspects of Transfer Commands
7.2.1.1 I3C Modes and Data Rates
1766 An I3C Controller implementer may choose which I3C Modes to support. The following I3C Modes are
1767 provided as guidance.
1768 Table 12 Supported I3C Transfer Modes
MODE Value I3C Transfer Mode Support
0x0 – 0x4 I3C SDR Mode Required
0x5 I3C HDR-Ternary Modes Optional
0x6 I3C HDR-DDR Mode Optional
0x7 Reserved –
1769 An I3C Controller implementer may choose differing interpretations for the specific data rates for values of
1770 the MODE field, which are used by the various Transfer Command types that the I3C Controller supports.
1771 Note:
1772 In this Command Descriptor format, the MODE field encodes both the transfer mode and the data
1773 rate, and the I2C field determines whether the indicated Target is an I3C Device or an I2C Device.
1774 Depending on the implementation, the specific data rates for the available the options for I3C SDR Mode
1775 transfers might depend on the specific clock logic used within the I3C Controller, or other clock logic used
1776 within the System. The following guidelines are provided, based on the maximum values.
70 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0  Specification for I3C TCRI
24-May-2022
Table 13 Maximum Values for I3C SDR Data Transfer Speeds
1777
MODE
|     | Field  | Listed Speed  | Maximum Sustainable Data Rate  |     |
| --- | ------ | ------------- | ------------------------------ | --- |
Value
|     | 0x0  | I3C SDR0  | 12.5 MHz, Standard SDR Speed, fSCL Max  |     |
| --- | ---- | --------- | --------------------------------------- | --- |
|     | 0x1  | I3C SDR1  | 8 MHz                                   |     |
|     | 0x2  | I3C SDR2  | 6 MHz                                   |     |
|     | 0x3  | I3C SDR3  | 4 MHz                                   |     |
|     | 0x4  | I3C SDR4  | 2 MHz                                   |     |

Specific user-defined data rates for the available options for I2C Mode transfers may also be implemented in
1778
1779  the I3C Controller.
| 1780  |     | Table 14 Maximum Values for I2C Data Transfer Speeds  |     |     |
| ----- | --- | ----------------------------------------------------- | --- | --- |
MODE
|     | Field  | Listed Speed  | Maximum Sustainable Data Rate  |     |
| --- | ------ | ------------- | ------------------------------ | --- |
Value
|     | 0x0  | I2C FM    | 400 KHz, I2C Fast Mode Speed, fSCL Max     |     |
| --- | ---- | --------- | ------------------------------------------ | --- |
|     | 0x1  | I2C FM+   | 1 MHz, I2C Fast Mode Plus Speed, fSCL Max  |     |
|     | 0x2  | I2C UDR1  | User Defined Data Rate 1                   |     |
I2C UDR2
|     | 0x3  |           | User Defined Data Rate 2  |     |
| --- | ---- | --------- | ------------------------- | --- |
|     | 0x4  | I2C UDR3  | User Defined Data Rate 3  |     |

1781  An I3C Controller implementer might choose to provide specific controls over the data rates used by the I3C
Bus Controller Logic, for various values supported by the MODE field in the various Transfer Command types
1782
1783  supported by the I3C Controller (see Section 7.2.2). If such parameters need to be controlled by the
1784  Application, then the implementer should define an interface to access these parameters. Note that such
1785  parameters for I3C SDR Mode timing might also include separate fields to affect the different transfer speeds
1786  for the Open-Drain vs. Push-Pull phases of I3C transactions in SDR Mode, including:
1787  • I3C Address Arbitration phase after a START condition
1788  • I3C Address Header after a Repeated START condition
1789  • Specific transfer rates for CCCs used during Bus Initialization and Dynamic Address Assignment:
1790  • SETDASA and SETAASA CCCs
1791  • ENTDAA CCC, including the various phases of the procedure with Dynamic Address Arbitration (per
the I3C Specification [MIPI02] at Section 5.1.4.2)
1792
For the various data rates, an implementer should also determine whether the I3C Controller and its I3C Bus
1793
1794  Controller Logic provide additional control over the clock speed (for I3C Pure Bus), or the duty cycle to limit
the effective minimum data rate (for I3C Mixed Buses) for specific Applications where the system requires
1795
1796  that the data rate stay above a given minimum transfer rate (per the I3C Specification  [MIPI02] at
1797  Section 5.1.2.4.1). If such control is needed, then the implementer should provide this control to the
Application via an interface.
1798
1799  An implementer should also define whether the I3C Controller supports Controller Clock Stalling (per the
1800  I3C Specification [MIPI02] at Section 5.1.2.5), and if so, whether such parameters that control Controller
Clock Stalling need to be controlled by the Application. If so, then the implementer should provide this
1801
1802  control to the Application via an interface.
|     |     | Copyright © 2022 MIPI Alliance, Inc.  |                         | 71  |
| --- | --- | ------------------------------------- | ----------------------- | --- |
|     |     |                                       | Public Release Edition  |     |

Specification for I3C TCRI Version 1.0
24-May-2022
7.2.1.2 Managed CCC Framing for Transfers
1803 I3C Controllers that support this Command Descriptor format shall automatically support Managed CCC
1804 Framing for all Transfer Commands.
1805 • Transition from Private Read/Write to CCC: If this Command Descriptor indicated a Private
1806 Read/Write transfer, and the next Command Descriptor indicates a CCC, the I3C Controller shall start the
1807 CCC framing automatically, as defined in Section 6.3.4.
1808 • The I3C Controller shall detect whether the next Command Descriptor is a CCC based on the value of
1809 fields MODE, CP, and CMD.
1810 • Transition from CCC to Private Read/Write: If this Command Descriptor indicated a CCC, and the next
1811 Command Descriptor indicates a Private Read/Write transfer, the I3C Controller shall end the CCC
1812 framing automatically, in an appropriate manner for the End of CCC Command (as defined in the I3C
1813 Specification at Section 5.1.9.2.1 [MIPI02]).
1814 • If this Command Descriptor was a Direct CCC, then the I3C Controller shall drive a Repeated START,
1815 followed by the Broadcast Address (i.e., 7’h7E), followed by another Repeated START to exit the
1816 Direct CCC framing in SDR Mode.
1817 For all Transfer Commands that are CCCs, the Application should ensure that the DEV_ADDRESS fields for
1818 such a sequence do indicate that the Target devices are I3C Devices (i.e., field I2C has a value of 1’b1).
1819 Note:
1820 Legacy I2C Target Devices do not support CCCs. Sending CCCs to Legacy I2C Target Devices is not
1821 recommended.
7.2.2 Command Descriptor
1822 The write-only Command Descriptor structure defines a transaction, including its parameters, and is sent by
1823 the Application to schedule a command to a Target Device on the I3C Bus while the I3C Controller is
1824 operating in Active Controller mode.
1825 The Command Descriptor is 64 bits (2 DWORDs) in length, and supports a number of common transfer types
1826 (see Section 6.2).
1827 All I3C Transfer Commands can be grouped into the supported Command Types shown in Table 15. This
1828 Specification defines a Command Descriptor structure for each listed Command Type, at the indicated
1829 Section. Table 15 also shows the value of the CMD_ATTR field, for each listed Command Type.
1830 Table 15 Supported Command Types for Command Descriptor, Format 2
Code Command Type Support CMD_ATTR Section
I Immediate Data Transfer Command Required 0x1 (*) 7.2.2.1
R Regular Transfer Command Required 0x0 (*) 7.2.2.2
C Combo Transfer Command Optional 0x3 (*) 7.2.2.3
M Internal Control Command N/A 0x7 N/A
A Address Assignment Command N/A 0x2 N/A
1831 Note:
1832 An Application might choose to support Format 2 in addition to Format 1, for specific operating
1833 contexts. If so, then the Application should map different values for the Direct addressed forms of
1834 Transfer Commands. See Annex A, Section A.2 for more details.
1835 Figure 13 provides a high-level overview of the Command Types supported by the Command Descriptor for
1836 all supported I3C Commands, showing one row per Command Type. For the defined Command Types, field
1837 DEV_ADDRESS holds the Target’s address for all transfer operations.
72 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0  Specification for I3C TCRI
24-May-2022

|     | F ie ld s  f | o r  I m m e d ia te |  D a ta   T r a n | s fe r   C o m m a n d |     |
| --- | ------------ | -------------------- | ----------------- | ---------------------- | --- |
B its  in  D W O R D 3 1 3 0 2 9 2 8 2 7 2 6 2 5 2 4 2 3 2 2 2 1 2 0 1 9 1 8 1 7 1 6 1 5 1 4 1 3 1 2 1 1 1 0 9 8 7 6 5 4 3 2 1 0
D W O R D  1  (N + 3 2 ) D A T A _ B Y T E _ 4 D A T A _ B Y T E _ 3 D A T A _ B Y T E _ 2 D A T A _ B Y T E _ 1  o r  D E F _ B Y T E
D W O R D  0  (N + 0 ) M O D E D T T D E V _ A D D R E S S C M D T ID C M D _ A T T R
|                    | F ie ld s  f | o r  R e g u la r   T | r a n s fe r   C o m | m a n d |     |
| ------------------ | ------------ | --------------------- | -------------------- | ------- | --- |
| B its  in  D W O R | D            |                       |                      |         |     |
3 1 3 0 2 9 2 8 2 7 2 6 2 5 2 4 2 3 2 2 2 1 2 0 1 9 1 8 1 7 1 6 1 5 1 4 1 3 1 2 1 1 1 0 9 8 7 6 5 4 3 2 1 0
D W O R D  1  (N + 3 2 ) D A T A _ L E N G T H R E S E R V E D D E F _ B Y T E
D W O R D  0  (N + 0 ) M O D E R D E V _ A D D R E S S C M D T ID C M D _ A T T R
|     | F ie ld s  f | o r  C o m b o  T | r a n s f e r  C o m | m a n d |     |
| --- | ------------ | ----------------- | -------------------- | ------- | --- |
B its  in  D W O R D 3 1 3 0 2 9 2 8 2 7 2 6 2 5 2 4 2 3 2 2 2 1 2 0 1 9 1 8 1 7 1 6 1 5 1 4 1 3 1 2 1 1 1 0 9 8 7 6 5 4 3 2 1 0
D W O R D  1  (N + 3 2 ) D A T A _ L E N G T H R E S E R V E D O F F S E T  o r  S U B O F F S E T
| D W O R D  0  (N + | 0 ) |     |     |     |     |
| ------------------ | --- | --- | --- | --- | --- |
M O D E D L P D E V _ A D D R E S S C M D T ID C M D _ A T T R
1838
Figure 13 Overview of Supported Command Types for Command Descriptor, Format 2
Note:
1839
1840  The Transfer Command formats for Format 2 are derived from the formats that are defined in version 1.1 of the I3C Host Controller Interface
1841  Specification [MIPI05]. These Transfer Commands are similar to Format 1, but some specific fields have been added or changed.

|     |     |     |     | Copyright © 2022 MIPI Alliance, Inc.  | 73  |
| --- | --- | --- | --- | ------------------------------------- | --- |
|     |     |     |     | Public Release Edition                |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
7.2.2.1  Immediate Data Transfer Command
1842  This section defines the Command Descriptor structure for Immediate Data Transfer commands.
1843  This structure directly contains data bytes to be transferred, and as a result is only useful for shorter Write-
1844  Type transfers, or CCCs that write data (i.e., write segments for Direct CCCs or Broadcast CCC messages;
1845  see Section 7.2.2.1.1). This structure shall not be used for Read-Type transfers (i.e., to receive data from a
1846  Device).
1847  Note:
1848  Immediate transfers are not CCC-specific, they can describe any transfer. The design intent is to
1849  provide the Application with a method for sending short, immediate transfers in order to reduce the
1850  number of transactions that would otherwise have to be made on internal busses.
1851  Table 16 Immediate Data Transfer Command Structure
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]          | Access  Value  |                                      |
| --------------- | -------------- | ------------------------------------ |
| 8  DATA_BYTE_4  | W  0x0         | Immediate Data Transfer Data Byte 4  |
[63:56]
Direct argument
| 8  DATA_BYTE_3  | W  0x0  | Immediate Data Transfer Data Byte 3  |
| --------------- | ------- | ------------------------------------ |
| [55:48]         |         | Direct argument                      |
| 8  DATA_BYTE_2  | W  0x0  | Immediate Data Transfer Data Byte 2  |
| [47:40]         |         | Direct argument                      |
8  DATA_BYTE_1 /  W  0x0  Immediate Data Transfer Data Byte 1 or DefByte
[39:32]  DEF_BYTE
Direct argument, optionally treated as the Defining Byte
(and thus placed before the Device Address).
1  TOC  W  0x0  Immediate Data Transfer Terminate on Completion
[31]  Controls what Bus condition is issued after completion of
the data transfer.
Values:
•  1’b0: RESTART: Issue Repeated START (Sr) at end of
data transfer
•  1’b1: STOP: Issue Stop (P) at end of data transfer
| 1  WROC  | W  0x0  | Immediate Data Transfer  |
| -------- | ------- | ------------------------ |
| [30]     |         | Response on Completion   |
Controls whether Response Status is required after
successful completion of the data transfer.
Note:
The Application may change the meaning of this field,
or whether this field is used.
Values:
•  1’b0: NOT_REQUIRED: Response Status is not required
•  1’b1: REQUIRED: Response Status is required
| 74  | Copyright © 2022 MIPI Alliance, Inc.  |     |
| --- | ------------------------------------- | --- |
|     | Public Release Edition                |     |

Version 1.0 Specification for I3C TCRI
24-May-2022
Size Memory Reset
Field Name Description
[Bits] Access Value
1 RNW W 0x0 Immediate Data Transfer
[29] Direction (RnW)
Identifies direction of the transfer.
This field shall always be set to 1’b0, because Immediate
transfers are valid for Write transactions only.
Values:
• 1’b0: WRITE: Write transfer
• 1’b1: Reserved, do not use
3 MODE W 0x0 Immediate Data Transfer
[28:26] Mode and Speed
Sets the Mode and speed for the I3C or I2C transfer.
Interpretation of this field depends on whether the Device is
in I3C Mode vs. I2C Mode (per the value in field I2C).
Values for I3C Mode:
• 0x0: I3C SDR0
Standard SDR Speed, fSCL Max (up to 12.5 Mhz)
• 0x1–0x4: I3C SDR1–SDR4
Reduced data rates (see Section 7.2.1)
• 0x5: I3C HDR-TSx
HDR-Ternary Mode
• 0x6: I3C HDR-DDR
HDR Double Data Rate Mode
• 0x7: Reserved
Values for I2C Mode:
• 0x0–0x4: I2C at supported data rates
(see Section 7.2.1)
• 0x5–0x7: Reserved
3 DTT W 0x0 Immediate Data Transfer
[25:23] Type and Byte Count
Number of valid data bytes to use in this Immediate Data
Transfer Descriptor.
Values 5-7 indicate that the first Data Byte shall be treated
as the Defining Byte, for CCCs with a Defining Byte.
Note:
This field should be set to a non-zero value, except for
valid transfers with no data bytes that only require an
ACK of a Dynamic Address (such as any Direct CCCs
that do not have any payload defined). Broadcast
CCCs with no subsequent bytes (such as SETAASA)
are also valid examples of zero-byte payloads.
Values:
• 0: No payload
• 1–4: N bytes are valid
• 5: Defining Byte + 0
• 6: Defining Byte + 1
• 7: Defining Byte + 2
Copyright © 2022 MIPI Alliance, Inc. 75
Public Release Edition

Specification for I3C TCRI  Version 1.0
  24-May-2022
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]          | Access  Value  |                          |
| --------------- | -------------- | ------------------------ |
| 7  DEV_ADDRESS  | W  0x0         | Immediate Data Transfer  |
| [22:16]         |                | Device Address           |
Indicates the valid Dynamic Address, for Read/Write
transfers and for Direct CCCs.
This field is ignored for Broadcast CCCs.
| 1  CP  | W  0x0  | Immediate Data Transfer  |
| ------ | ------- | ------------------------ |
| [15]   |         | Command Present          |
Indicates whether field CMD is valid for a CCC or HDR
Transfer.
Values:
•  1’b0: TRANSFER: This structure describes an SDR
transfer, so the CMD field is not valid.
•  1’b1: CCC_HDR: This structure describes a CCC or HDR
transfer, so field CMD is valid.
| 8  CMD  | W  0x0  | Immediate Data Transfer       |
| ------- | ------- | ----------------------------- |
| [14:7]  |         | CCC / HDR Command Code Value  |
Specifies the I3C Command code. The interpretation of this
field depends on field CP.
For CCC: 8 bits (i.e., the Command Code, see Section 6.3)
For HDR: 7 bits (i.e., bits 13:7 are used for the lower 7 bits
of the HDR-DDR or HDR-TSx Command Code, and the
upper bit is determined by bit 29; bit 14 is ignored).
| 1  I2C  | W  0x0  | Immediate data Transfer  |
| ------- | ------- | ------------------------ |
| [6]     |         | Device Type              |
Values:
•  1’b0: I3C: I3C Device
1’b1: I2C: Legacy I2C Device
•
| 3  TID  | W  0x0  | Immediate Data Transfer  |
| ------- | ------- | ------------------------ |
| [5:3]   |         | Transaction ID           |
Used as an identification tag for this command.
This field shall be populated by the Application, and the
same value shall be reflected in the Response Descriptor.
| 3  CMD_ATTR  | W  0x0  | Immediate Data Transfer  |
| ------------ | ------- | ------------------------ |
| [2:0]        |         | Command Attribute        |
Command Type, defining the format of the other fields.
Values:
•  0x1: IMMED_DATA_XFER: Immediate Data Transfer
•  All other values are defined for other Command Types, or
reserved for future use.

| 76  | Copyright © 2022 MIPI Alliance, Inc.  |     |
| --- | ------------------------------------- | --- |
|     | Public Release Edition                |     |

| Version 1.0  |     |     |     |     | Specification for I3C TCRI  |     |     |
| ------------ | --- | --- | --- | --- | --------------------------- | --- | --- |
24-May-2022
| 7.2.2.1.1  | Usage for CCCs with Managed CCC Framing  |     |     |     |     |     |     |
| ---------- | ---------------------------------------- | --- | --- | --- | --- | --- | --- |
1852  An Immediate Data Transfer command that is used for a CCC with Managed CCC Framing (per Section 6.3)
1853  shall have field CP set to 1’b1, and field MODE set to any valid value that indicates a transfer in SDR Mode.
Field I2C should also be set to 1’b0.
1854
1855  The Application shall provide the I3C Common Command Code in field CMD. If the Transfer Command
1856  indicates that the CCC is sent with a Defining Byte, then the Application shall also set field DTT appropriately,
per Table 8. For Direct Write or Direct SET CCCs, field DTT shall also indicate the length of the data payload
1857
1858  that is sent to the addressed I3C Target Address or Group Address, as part of Direct CCC framing (per
1859  Section 6.3).
1860  • If the CCC is sent with a Defining Byte, then bits 39:22 (i.e., field DEF_BYTE) indicates the Defining
Byte value, and subsequent fields (i.e., fields DATA_BYTE_2 and DATA_BYTE_3) may be used for
1861
1862  optional first and second bytes (respectively) of the data payload.
1863  • If the CCC is sent without a Defining byte, then bits 39:22 (i.e., field DATA_BYTE_1) may be used for
the first byte of the optional data payload; and subsequent fields (i.e., DATA_BYTE_2, DATA_BYTE_3
1864
1865  and DATA_BYTE_4) may be used for optional second, third and fourth bytes (respectively) of the data
1866  payload.
1867  This Transfer Command may also be used for a Broadcast CCC. In this case, the Application shall set field
1868  DEV_ADDRESS to zero, since the I3C Controller ignores this field for Broadcast CCCs.
1869  Table 17 Immediate Data Transfer Command Usage for CCCs and Defining Bytes
CCC Sent
|     | Field DTT  |     | First Byte  | Second Byte  | Third Byte  | Fourth Byte  |     |
| --- | ---------- | --- | ----------- | ------------ | ----------- | ------------ | --- |
with Defining
|     | Value  |     | is in Field  | is in Field  | is in Field  | is in Field  |     |
| --- | ------ | --- | ------------ | ------------ | ------------ | ------------ | --- |
Byte?
|     | 0   |      | –            | –            | –            | –            |     |
| --- | --- | ---- | ------------ | ------------ | ------------ | ------------ | --- |
|     | 1   |      | DATA_BYTE_1  | –            | –            | –            |     |
|     | 2   | No   | DATA_BYTE_1  | DATA_BYTE_2  | –            | –            |     |
|     | 3   |      | DATA_BYTE_1  | DATA_BYTE_2  | DATA_BYTE_3  | –            |     |
|     | 4   |      | DATA_BYTE_1  | DATA_BYTE_2  | DATA_BYTE_3  | DATA_BYTE_4  |     |
|     | 5   |      | –            | –            | –            | –            |     |
|     | 6   | Yes  | DATA_BYTE_2  | –            | –            | –            |     |
|     | 7   |      | DATA_BYTE_2  | DATA_BYTE_3  | –            | –            |     |

1870  Note:
An Immediate Data Transfer command that indicates a CCC with a Defining Byte does not support
1871
1872  more than two data bytes for the data payload. In order to send a CCC with a Defining Byte and more
1873  than two data bytes for the data payload, the Application must use the Regular Data Transfer
1874  command (see Section 7.2.2.2.1).

|     |     |     | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     | 77  |
| --- | --- | --- | ------------------------------------- | --- | --- | --- | --- |
|     |     |     | Public Release Edition                |     |     |     |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
7.2.2.2  Regular Data Transfer Command
1875  This section defines the Command Descriptor structure for Regular Data Transfer commands. This Transfer
1876  Command  type  may  be  used  for  any  Private  Read  or  Private Write,  as  well  as  many  CCCs  (per
Section 7.2.2.2.1).
1877
1878  The Command Descriptor structure for Regular Data Transfer commands indicates that the transfer should
1879  use a data buffer or queue, based on the operating mode of the Application.
Table 18 Regular Data Transfer Command Structure
1880
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]           | Access  Value  |                |
| ---------------- | -------------- | -------------- |
| 16  DATA_LENGTH  | W  0x0         | Data Transfer  |
| [63:48]          |                | Data Length    |
Indicates the number of bytes to be transferred.
Note:
This field should be set to a non-zero value.
For valid transfers with no data bytes that only
require an ACK of a Dynamic Address (such as
any Direct CCCs that do not have payload
defined), Immediate Data Transfer Commands
should typically be used instead.
| 8  RESERVED  | –  –  | –   |
| ------------ | ----- | --- |
[47:40]
Data Transfer
| 8  DEF_BYTE  | W  0x0  |     |
| ------------ | ------- | --- |
Defining Byte for Present CCC
[39:32]
Valid if field DBP contains 1’b1
| 1  TOC  | W  0x0  | Data Transfer            |
| ------- | ------- | ------------------------ |
| [31]    |         | Terminate on Completion  |
Controls what Bus condition will be issued after
completion of the transfer, per Section 6.2.5.
Values:
•  1’b0: RESTART: Issue Repeated START (Sr) at end
of transfer
•  1’b1: STOP: Issue Stop (P) at end of transfer
| 1  WROC  | W  0x0  | Data Transfer           |
| -------- | ------- | ----------------------- |
| [30]     |         | Response on Completion  |
Controls whether Response Status is required after
successful completion of the data transfer.
Note:
The Application may change the meaning of this
field, or whether this field is used.
Values:
•  1’b0: NOT_REQUIRED: Response Status is not
required
•  1’b1: REQUIRED: Response Status is required
| 78  | Copyright © 2022 MIPI Alliance, Inc.  |     |
| --- | ------------------------------------- | --- |
|     | Public Release Edition                |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]  | Access  Value  |                  |     |
| ------- | -------------- | ---------------- | --- |
| 1  RNW  | W  0x0         | Data Transfer    |     |
| [29]    |                | Direction (RnW)  |     |
Identifies the direction of this transfer.
Values:
•  1’b0: WRITE: Write transfer
•  1’b1: READ: Read transfer
| 3  MODE  | W  0x0  | Data Transfer   |     |
| -------- | ------- | --------------- | --- |
| [28:26]  |         | Speed and Mode  |     |
Sets the Mode and speed for the I3C or I2C transfer.
Interpretation of this field depends on whether the
Device is in I3C Mode vs. I2C Mode (per the value in
field I2C).
Values for I3C Mode:
•  0x0: I3C SDR0
Standard SDR Speed, fSCL Max (up to 12.5 MHz)
•  0x1–0x4: I3C SDR1–SDR4
Reduced data rates (see Section 7.2.1)
•  0x5: I3C HDR-TSx
HDR-Ternary Mode
•  0x6: I3C HDR-DDR
HDR Double Data Rate Mode
•  0x7: Reserved
Values for I2C Mode:
•  0x0–0x4: I2C at supported data rates (see
Section 7.2.1)
•  0x5–0x7: Reserved
| 1  DBP  | W  0x0  | Data Transfer                  |     |
| ------- | ------- | ------------------------------ | --- |
| [25]    |         | Defining Byte for CCC Present  |     |
If this field contains 1’b1, then field DEF_BYTE contains
the Defining Byte value.
| 1  SHORT_READ_ERR  | W  0x0  | Data Transfer        |     |
| ------------------ | ------- | -------------------- | --- |
| [24]               |         | Short Read Is Error  |     |
Controls whether a ‘short’ Read-type transfer is
permitted or treated as an error.
Note:
This field is valid for I3C Read-type transfers only.
For I3C Write-type transfers or I2C transfers, the
Application shall always set this field to 1’b0.
Values (for I3C Read transfers):
•  1’b0: ALLOW_SHORT_READ: All successful Read
transfers are permitted, for lengths up to and
including field DATA_LENGTH.
•  1’b1: SHORT_READ_IS_ERROR: Only allowed if field
RNW is set to 1’b1. A ‘short’ Read transfer is not
permitted, and will be treated as a transfer error. If
the indicated Target Device does not return the
number of bytes requested via field DATA_LENGTH,
then this Read transfer shall be treated as an error
and the I3C Controller shall halt after the end of the
Read-type transfer (see Section 6.2.1).
|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 79  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]       | Access  Value  |     |
| ------------ | -------------- | --- |
| 1  RESERVED  | –  –           | –   |
[23]
| 7  DEV_ADDRESS  | W  0x0  | Data Transfer   |
| --------------- | ------- | --------------- |
| [22:16]         |         | Device Address  |
Indicates the valid Dynamic Address, for Read/Write
transfers and for Direct CCCs.
This field is ignored for Broadcast CCCs.
| 1  CP  | W  0x0  | Data Transfer  |
| ------ | ------- | -------------- |
Command Present
[15]
Indicates whether field CMD is valid for a CCC or HDR
Transfer.
Values:
•  1’b0: TRANSFER: This structure describes an SDR
transfer, so the CMD field is not valid.
•  1’b1: CCC_HDR: This structure describes a CCC or
HDR transfer, so field CMD is valid.
| 8  CMD  | W  0x0  | Data Transfer  |
| ------- | ------- | -------------- |
CCC / HDR Command Code Value
[14:7]
Specifies the I3C Command code. The interpretation
of this field depends on field CP.
•  For CCC: 8 bits (i.e., the Command Code; see
Section 6.3)
•  For HDR: 7 bits (i.e., bits 13:7 are used for the
lower 7 bits of the HDR-DDR or HDR-TSx
Command Code, and the upper bit is determined by
bit 29; bit 14 is ignored).
| 1  I2C  | W  0x0  | Data Transfer  |
| ------- | ------- | -------------- |
| [6]     |         | Device Type    |
Values:
•  1’b0: I3C: I3C Device
•  1’b1: I2C: Legacy I2C Device
| 3  TID  | W  0x0  | Data Transfer   |
| ------- | ------- | --------------- |
| [5:3]   |         | Transaction ID  |
Identification tag for this command.
| 3  CMD_ATTR  | W  0x0  | Data Transfer      |
| ------------ | ------- | ------------------ |
| [2:0]        |         | Command Attribute  |
Command Type, defining the format of the other fields.
Values:
•  0x0: XFER: Regular Transfer
•  All other values are defined for other Command
Types, or reserved for future use.

| 80  | Copyright © 2022 MIPI Alliance, Inc.  |     |
| --- | ------------------------------------- | --- |
|     | Public Release Edition                |     |

Version 1.0 Specification for I3C TCRI
24-May-2022
7.2.2.2.1 Usage for CCCs with Managed CCC Framing
1881 A Regular Data Transfer command that is used for a CCC with Managed CCC Framing (per Section 6.3)
1882 shall have field CP set to 1’b1, and field MODE set to any valid value that indicates a transfer in SDR Mode.
1883 The Application shall provide the I3C Common Command Code in field CMD. If the Transfer Command
1884 indicates that the CCC is sent with a Defining Byte, then the Application shall also set field DBP to 1’b1 and
1885 provide the Defining Byte value in field DEF_BYTE. However, if the CCC is sent without a Defining Byte,
1886 then the Application shall set field DBP to 1’b0, and the value of field DEF_BYTE shall be ignored.
1887 This Transfer Command type may be used for Broadcast CCC messages, or for any type of Direct CCC
1888 segments (i.e., a single segment per Transfer Command):
1889 • For a Broadcast CCC message or a single Write segment of a Direct CCC (i.e., Direct Write or Direct
1890 SET), the Application shall set field RNW to indicate a Write-Type transfer, and shall provide the write
1891 data to the appropriate Queue/Buffer, per the operating mode.
1892 • For a single Read segment of a Direct CCC (i.e., Direct Read or Direct GET), the Application shall set
1893 field RNW to indicate a Read-Type transfer, and the data returned from the indicated I3C Target Device
1894 shall be read from the appropriate Queue/Buffer, per the operating mode.
1895 • Additionally, for a Broadcast CCC message, the Application shall set field DEV_ADDRESS to zero, since
1896 the I3C Controller ignores this field for Broadcast CCCs.
7.2.2.3 Combo Transfer (Write + Write/Read) Command
1897 This section defines the Command Descriptor structure for Combo Transfer commands.
1898 Each Combo Transfer Command Descriptor describes a combined Write + Read/Write operation. These two
1899 phases of the Combo Transfer shall be separated by an appropriate condition that restarts the framing:
1900 • For both phases in SDR Mode: Repeated START.
1901 • For the first phase in SDR Mode and the second phase in an HDR Mode: Repeated START, followed
1902 by the CCC to enter the appropriate HDR Mode (i.e., using the ENTHDR0–ENTHDR7 CCCs, as defined
1903 in version 1.1.1 of the I3C Specification [MIPI02] at Section 5.1.9.3.9).
1904 • For both phases in HDR Mode: The HDR Restart Pattern.
1905 The Combo Transfer Command Descriptor varies in format, depending on the particular transfer operation
1906 being requested on the I3C Bus:
1907 • SDR:
1908 S + ADR + ACK + Offset + Sr + ADR + Data + P
1909 • HDR (16_BIT_SUBOFFSET == 1, Length first):
1910 S + WrCmd + ADR + Length (16 bits) + Offset (16 bits) + Sr + CMD + ADR + Data + P
1911 • HDR (16_BIT_SUBOFFSET == 1, Length second):
1912 S + WrCmd + ADR + Offset (16 bits) + Length (16 bits) + Sr + CMD + ADR + Data + P
1913 • HDR (16_BIT_SUBOFFSET == 1, no Length):
1914 S + WrCmd + ADR + Offset (16 bits) + Sr + CMD + ADR + Data + P
1915 • HDR (16_BIT_SUBOFFSET == 0, Length first):
1916 S + WrCmd + ADR + Length (8 bits) and Offset (8 bits) + Sr + CMD + ADR + Data + P
1917 • HDR (16_BIT_SUBOFFSET == 0, Length second):
1918 S + WrCmd + ADR + Offset (8 bits) and Length (8 bits) + Sr + CMD + ADR + Data + P
1919 • HDR (16_BIT_SUBOFFSET == 0, no Length):
1920 S + WrCmd + ADR + All 0s padding (8 bits) and Offset (8 bits) + Sr + CMD + ADR + Data + P
1921 For Combo Transfers where the first phase is in an HDR Mode, the value of WrCMD is derived from the
1922 provided value of the 8-bit CMD field in the Command Descriptor. The I3C Controller shall mask off the high
1923 bit from the CMD field:
1924 WrCmd = CMD & 0x7F
Copyright © 2022 MIPI Alliance, Inc. 81
Public Release Edition

| Specification for I3C TCRI  |     |     |     |     |     |     |     |     |     | Version 1.0  |     |
| --------------------------- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ------------ | --- |
|                             |     |     |     |     |     |     |     |     |     | 24-May-2022  |     |
1925  Note:
1926  Per the I3C Specification [MIPI02], the command codes for Write are 0x00–0x7F, and for Read the
1927  command codes are 0x80–0xFF.
1928  If the FIRST_PHASE_MODE field is set to 0, then the first write on the I3C Bus is executed in SDR Mode
1929  (i.e., SDR0), and the speed and Mode of the second phase are determined by the MODE field.
| Command Descriptor Structure Lo |     |     | Command  |     |     |     |     |     |     |     |     |
| ------------------------------- | --- | --- | -------- | --- | --- | --- | --- | --- | --- | --- | --- |
Descriptor
Command Descriptor Structure Hi
| BLP=0 IOC | Block Size |     |     |     |     |     |     |     |     |     |     |
| --------- | ---------- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
Pointer to physical
| Data Buffer List Ptr Lo |     |     | memory or Scatter  |     |     |     | Protocol specific  |     |     |     |     |
| ----------------------- | --- | --- | ------------------ | --- | --- | --- | ------------------ | --- | --- | --- | --- |
| Data Buffer List Ptr Hi |     |     | Gather list        |     |     |     | (hardcoded)        |     |     |     |     |
Specified by Combo
Command Descriptor
a) SDR+SDR
Specified by Transfer
| First phase (SDR) |        |        | Second phase (SDR) |     |     |     |                     | Descriptor |     |     |     |
| ----------------- | ------ | ------ | ------------------ | --- | --- | --- | ------------------- | ---------- | --- | --- | --- |
| S                 |        |        |                    | P   |     |     | Derived from Combo  |            |     |     |     |
| ADR               | OFFSET | Sr ADR | DATA               |     |     |     |                     |            |     |     |     |
| Sr                |        |        |                    | Sr  |     |     | Command Descriptor  |            |     |     |     |
b) SDR+HDR
| First phase (SDR) |     |     |     | Second phase (HDR) |     |     |     |     |     |     |     |
| ----------------- | --- | --- | --- | ------------------ | --- | --- | --- | --- | --- | --- | --- |
Command Word
| S ADR | OFFSET | Sr ENTHDR  | Code for       |     | ADR | DATA | CRC P |     |     |     |     |
| ----- | ------ | ---------- | -------------- | --- | --- | ---- | ----- | --- | --- | --- | --- |
| Sr    |        |            | CCC Write/Read |     |     |      | Sr    |     |     |     |     |
c) HDR+HDR (8-bit Offset, Length first)
|           |           | First phase (HDR) |                          |        |     |              | Second phase (HDR) |      |     |     |     |
| --------- | --------- | ----------------- | ------------------------ | ------ | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|           |           | Command Word      | Data (Length and Offset) |        |     | Command Word |                    | Data |     |     |     |
| S ENTHDR  | Code for  |                   |                          |        | HDR | Code for     |                    |      |     | P   |     |
| Sr CCC    | Write     | ADR               | Length                   | Offset | Sr  | Write/Read   | ADR                | DATA | CRC | Sr  |     |
d) HDR+HDR (8-bit Offset, Length second)
|           |           | First phase (HDR) |                          |        |     |              | Second phase (HDR) |      |     |     |     |
| --------- | --------- | ----------------- | ------------------------ | ------ | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|           |           | Command Word      | Data (Length and Offset) |        |     | Command Word |                    | Data |     |     |     |
| S ENTHDR  | Code for  |                   |                          |        | HDR | Code for     |                    |      |     | P   |     |
|           |           | ADR               | Offset                   | Length |     |              | ADR                | DATA | CRC |     |     |
| Sr CCC    | Write     |                   |                          |        | Sr  | Write/Read   |                    |      |     | Sr  |     |
e) HDR+HDR (8-bit Offset, no Length)
|           |           | First phase (HDR) |                          |        |     |              | Second phase (HDR) |      |     |     |     |
| --------- | --------- | ----------------- | ------------------------ | ------ | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|           |           | Command Word      | Data (Length and Offset) |        |     | Command Word |                    | Data |     |     |     |
| S ENTHDR  | Code for  |                   |                          |        | HDR | Code for     |                    |      |     | P   |     |
|           |           | ADR               | all 0s                   | Offset |     |              | ADR                | DATA | CRC |     |     |
| Sr CCC    | Write     |                   |                          |        | Sr  | Write/Read   |                    |      |     | Sr  |     |
f) HDR+HDR (16-bit Offset, Length first)
|     |     | First phase (HDR) |                          |     |                          |     |     |              | Second phase (HDR) |      |     |
| --- | --- | ----------------- | ------------------------ | --- | ------------------------ | --- | --- | ------------ | ------------------ | ---- | --- |
|     |     | Command Word      | Data (Length and Offset) |     | Data (Length and Offset) |     |     | Command Word |                    | Data |     |
S ENTHDR  Code for  ADR Length Length Offset Offset HDR Code for  ADR DATA CRC P
| Sr CCC | Write |     |     |     |     |     | Sr  | Write/Read |     |     | Sr  |
| ------ | ----- | --- | --- | --- | --- | --- | --- | ---------- | --- | --- | --- |
g) HDR+HDR (16-bit Offset, Length second)
|     |     | First phase (HDR) |                          |     |                          |     |     |              | Second phase (HDR) |      |     |
| --- | --- | ----------------- | ------------------------ | --- | ------------------------ | --- | --- | ------------ | ------------------ | ---- | --- |
|     |     | Command Word      | Data (Length and Offset) |     | Data (Length and Offset) |     |     | Command Word |                    | Data |     |
S ENTHDR  Code for  ADR Offset Offset Length Length HDR Code for  ADR DATA CRC P
| Sr CCC | Write |     |     |     |     |     | Sr  | Write/Read |     |     | Sr  |
| ------ | ----- | --- | --- | --- | --- | --- | --- | ---------- | --- | --- | --- |
h) HDR+HDR (16-bit Offset, no Length)
|     |     | First phase (HDR) |                          |     |     |              | Second phase (HDR) |      |     |     |     |
| --- | --- | ----------------- | ------------------------ | --- | --- | ------------ | ------------------ | ---- | --- | --- | --- |
|     |     | Command Word      | Data (Length and Offset) |     |     | Command Word |                    | Data |     |     |     |
S ENTHDR  Code for  ADR Offset Offset HDR Code for  ADR DATA CRC P
| Sr CCC | Write |     |     |     | Sr  | Write/Read |     |     |     | Sr  |     |
| ------ | ----- | --- | --- | --- | --- | ---------- | --- | --- | --- | --- | --- |
1930
Figure 14 I3C Bus Activity for Combo Transfer
| 82  |     |     | Copyright © 2022 MIPI Alliance, Inc.  |                         |     |     |     |     |     |     |     |
| --- | --- | --- | ------------------------------------- | ----------------------- | --- | --- | --- | --- | --- | --- | --- |
|     |     |     |                                       | Public Release Edition  |     |     |     |     |     |     |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
In the case of a Combo Transfer Command failure due to a NACK or a transfer that was aborted early, the
1931
1932  returned status in the Response Descriptor shall indicate the phase of the transaction in which the failure
1933  actually occurred. The Application shall accommodate this returned status in its error handling flow.
1934  • For errors in the first phase of a Combo transfer:
1935  • If the indicated Target Device NACKs the Write, then the I3C Controller shall return an error code 0x5
1936  (NACK) in field ERR_STATUS.
1937  • If the transfer is aborted early, then the I3C Controller shall return an error code 0x9 (BUS_ABORTED)
1938  in field ERR_STATUS.
1939  • For errors in the second phase of a Combo transfer:
1940  • If the indicated Target Device NACKs the Write or Read as part of the second phase, then the I3C
1941  Controller shall return an error code 0xC (Transfer Type Specific: COMBO_NACK_2ND) in field
1942  ERR_STATUS.
1943  • If the second phase of the transfer is aborted early, then the I3C Controller shall return an error code
1944  0xD (Transfer Type Specific: COMBO_BUS_ABORTED_2ND) in field ERR_STATUS.
• These error codes are defined in Section 6.4.1.
1945
1946  Table 19 Combo (Write + Write/Read) Transfer Command Structure
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]           | Access  Value  |                 |     |
| ---------------- | -------------- | --------------- | --- |
| 16  DATA_LENGTH  | W  0x0         | Combo Transfer  |     |
| [63:48]          |                | Data Length     |     |
Number of bytes to be transferred.
Note:
This field must be set to non-zero value.
| 16  OFFSET / SUBOFFSET  | –  –  | Combo Transfer       |     |
| ----------------------- | ----- | -------------------- | --- |
| [47:32]                 |       | Offset / Sub-Offset  |     |
Offset of the target operation
| 1  TOC  | W  0x0  | Combo Transfer  |     |
| ------- | ------- | --------------- | --- |
Terminate on Completion
[31]
Controls what Bus condition is issued after
completion of the transfer.
Values:
•  1’b0: RESTART: Issue Repeated START (Sr)
at end of transfer
•  1’b1: STOP: Issue Stop (P) at end of transfer
| 1  WROC  | W  0x0  | Combo Transfer          |     |
| -------- | ------- | ----------------------- | --- |
| [30]     |         | Response on Completion  |     |
Controls whether Response Status is required
after successful completion of the combo
transfer.
Note:
The Application may change the meaning of
this field, or whether this field is used.
Values:
•  1’b0: NOT_REQUIRED: Response Status is not
required
•  1’b1: REQUIRED: Response Status is required
|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 83  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI  Version 1.0
  24-May-2022
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]  | Access  Value  |                  |
| ------- | -------------- | ---------------- |
| 1  RNW  | W  0x0         | Combo Transfer   |
| [29]    |                | Direction (RnW)  |
Sets transfer direction. This applies only to the
second phase; the first phase is always a Write
transfer.
Values:
•  1’b0: WRITE: Second phase is a Write transfer
•  1’b1: READ: Second phase is a Read transfer.
The Combo Transfer Command does not
support ‘short’ Read transfers (see
Section 6.2.1).
| 3  MODE  | W  0x0  | Combo Transfer  |
| -------- | ------- | --------------- |
| [28:26]  |         | Speed and Mode  |
Sets the Mode and speed for the I3C or I2C
transfer.
Interpretation of this field depends on whether
the Device is in I3C Mode vs. I2C Mode (per the
value in field I2C).
Values for I3C Mode:
•  0x0: I3C SDR0
Standard SDR Speed, fSCL Max (up to
12.5 MHz)
•  0x1–0x4: I3C SDR1–SDR4
Reduced data rates (see Section 7.2.1)
•  0x5: I3C HDR-TSx
HDR-Ternary Mode
•  0x6: I3C HDR-DDR
HDR Double Data Rate Mode
•  0x7: Reserved
Values for I2C Mode:
•  0x0–0x4: I2C at supported data rates (see
Section 7.2.1)
•  0x5–0x7: Reserved
| 1  16_BIT_SUBOFFSET  | W  0x0  | Combo Transfer   |
| -------------------- | ------- | ---------------- |
| [25]                 |         | Sub Offset Size  |
Sets Sub-Offset length to 8 or 16 bits.
Values:
•  1’b0: 8_BIT_SUBOFFSET: Sub-offset is 8 bits
long. Value is encoded in Lower Byte of the
OFFSET / SUBOFFSET field.
•  1’b1: 16_BIT_SUBOFFSET: Sub-offset is 16 bits
long
| 84  Copyright © 2022 MIPI Alliance, Inc.  |                         |     |
| ----------------------------------------- | ----------------------- | --- |
|                                           | Public Release Edition  |     |

Version 1.0  Specification for I3C TCRI
24-May-2022
| Size  | Memory  Reset  |     |     |
| ----- | -------------- | --- | --- |
Field Name  Description
| [Bits]                   | Access  Value  |                             |     |
| ------------------------ | -------------- | --------------------------- | --- |
| 2  DATA_LENGTH_POSITION  | W  0x0         | Data Length Field Position  |     |
[24:23]
Indicates whether and where to put Data Length
(DATA_LENGTH) in the first phase of the transfer.
This field is only applicable if First phase of the
transfer is executed in HDR Mode.
Whether 8 bits vs. 16 bits of the Data Length field
is used is indicated with field
16_BIT_SUBOFFSET. In the case of 8 bits, it is
encoded in Lower Byte of field DATA_LENGTH.
Values:
•  2’b0: NO: Do not put Length field
•  2’b1: FIRST: Put Length as first field
•  2’b2: SECOND: Put Length as second field
•  2’b3: RESERVED: Don’t use
| 7  DEV_ADDRESS  | W  0x0  | Combo Transfer  |     |
| --------------- | ------- | --------------- | --- |
| [22:16]         |         | Device Address  |     |
Indicates the valid Dynamic Address, for
Read/Write transfers and for Direct CCCs.
This field is ignored for Broadcast CCCs.
| 1  FIRST_PHASE_MODE  | W  0x0  | Combo Transfer    |     |
| -------------------- | ------- | ----------------- | --- |
| [15]                 |         | First Phase Mode  |     |
Indicates whether the first phase of the Combo
Transfer is executed in SDR Mode, vs. the Mode
indicated by the MODE field.
Values:
•  1’b0: SDR: First phase is executed in SDR
Mode
•  1’b1: MODE: First phase is executed in the
Mode indicated by the MODE field
| 8  CMD  | W  0x0  | Combo Transfer          |     |
| ------- | ------- | ----------------------- | --- |
| [14:7]  |         | HDR Command Code Value  |     |
•  For HDR: Contains the lower 7 bits of the
HDR-DDR or HDR-TSx Command code (i.e.,
bits 13:7 are used, and bit 14 is ignored). The
I3C Controller shall automatically use the
correct upper bit for the second phase, as
determined by bit 29.
•  For SDR: This field is reserved, and shall be
set to zero.
| 1  I2C  | W  0x0  | Combo Transfer  |     |
| ------- | ------- | --------------- | --- |
Device Type
[6]
Values:
•  1’b0: I3C: I3C Device
•  1’b1: I2C: Legacy I2C Device
| 3  TID  | W  0x0  | Combo Transfer  |     |
| ------- | ------- | --------------- | --- |
Transaction ID
[5:3]
Identification tag for the command.
|     | Copyright © 2022 MIPI Alliance, Inc.  |     | 85  |
| --- | ------------------------------------- | --- | --- |
|     | Public Release Edition                |     |     |

Specification for I3C TCRI Version 1.0
24-May-2022
Size Memory Reset
Field Name Description
[Bits] Access Value
3 CMD_ATTR W 0x0 Combo Transfer
[2:0] Command Attribute
Command Type, defining the format of the other
fields.
Values:
• 0x3: WWR_COMBO_XFER: Write + Write/Read
Combo Transfer
• All other values are defined for other
Command Types, or reserved for future use.
1947 Note:
1948 Compared with Format 1, Format 2 does not have an equivalent for field CP, since this field is not
1949 required for Combo Transfers.
7.2.2.4 Internal Control Command
1950 Applications can also define specific Internal Control Commands that can be used for any purpose, including
1951 configuring the I3C Controller or other functional logic. Internal Control Commands can be enqueued on
1952 their own, or framed with other Transfer Commands as modifiers or qualifiers to how the I3C Controller or
1953 other functional logic processes transactions, initiates other actions or methods on the I3C Bus.
1954 An Internal Control Command shares the same general format, with field CMD_ATTR set to 0x7. The
1955 remaining fields in the Command descriptor are available for the Application to define for other purposes
1956 and are not defined in this Specification.
7.2.2.5 Address Assignment Command
1957 Applications can also define specific Address Assignment Commands that are used for the special task of
1958 Dynamic Address Assignment using any of its supported methods. Address Assignment Commands can be
1959 enqueued on their own, or in sequences. In most cases, Address Assignment Commands should not be
1960 intermixed with other Transfer Commands.
1961 An Address Assignment Command shares the same general format, with field CMD_ATTR set to 0x2. The
1962 remaining fields in the Command Descriptor are available for the Application to define for other purposes
1963 and are not defined in this Specification.
86 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
7.2.3 Response Descriptor
1964 The Response Descriptor is a read-only structure describing the success or failure of a Transfer Command,
1965 and the amount of data transferred.
1966 The Response Descriptor is 32 bits (i.e., 1 DWORD) in length.
1967 Table 20 Response Descriptor Structure
Size Memory Reset
Field Name Description
[Bits] Access Value
4 ERR_STATUS R 0x0 Response Error Status
[31:28] Indicates the Response status for the processed
command (i.e., either success or the error type
encountered).
Error codes are described in Section 6.4.1.
Values:
• 0x0: SUCCESS: Transfer successful, no error.
• 0x1: CRC: CRC Error
• 0x2: PARITY: Parity Error
• 0x3: FRAME: Frame Error
• 0x4: ADDR_HEADER: Address Header Error
• 0x5: NACK: Address NACK’ed or Dynamic Address
Assignment NACK’ed
• 0x6: OVL: Receive Overflow or Transfer Underflow
Error
• 0x7: I3C_SHORT_READ_ERR: Target returned fewer
data bytes than requested in field DATA_LENGTH of a
Transfer Command that did not permit a ‘short’ read
(per Section 6.2.1 and Section 7.2.2.2)
• 0x8: HC_ABORTED: Aborted (i.e., terminated) by I3C
Controller due to internal error
• 0x9: Transfer terminated due to Bus action:
• For I2C: I2C_WR_DATA_NACK:
Aborted due to NACK received during an I2C Write
Data transfer
• For I3C: BUS_ABORTED:
Aborted due to Early Termination, or Target not
completing read or write of data phase of transfer
• 0xA: NOT_SUPPORTED: Command with specific
parameters not supported by the I3C Controller
implementation (e.g., specific Internal Control codes
may not be supported)
• 0xB: RESERVED
• 0xC–0xF: Transfer Type Specific Errors, defined for
specific transfer types
4 TID R 0x0 Command/Response Transaction ID
[27:24] Identification tag for the command.
This value shall match the value of field TID, for a
previously enqueued Command Descriptor that was sent
on the Bus.
Values:
• 0x0–0xF: Valid Transaction IDs
Copyright © 2022 MIPI Alliance, Inc. 87
Public Release Edition

Specification for I3C TCRI  Version 1.0
  24-May-2022
| Size  | Memory  Reset  |     |
| ----- | -------------- | --- |
Field Name  Description
| [Bits]       | Access  Value  |     |
| ------------ | -------------- | --- |
| 8  RESERVED  | –  –           | –   |
[23:16]
| 16  DATA_LENGTH  | R  0x0  | Data Length / Device Count                         |
| ---------------- | ------- | -------------------------------------------------- |
| [15:0]           |         | The meaning of this field depends on the context:  |
For Write Transfer: Remaining data length (in bytes)
For Read Transfer: Received data length (in bytes)
For Internal Control or Address Assignment:
Application may use for any purpose

| 88  | Copyright © 2022 MIPI Alliance, Inc.  |     |
| --- | ------------------------------------- | --- |
|     | Public Release Edition                |     |

Version 1.0 Specification for I3C TCRI
24-May-2022
Annex A Implementation Guidance
A.1 Application Capability Reporting
1968 I3C Applications that conform to this I3C TCRI Specification should report the following capabilities and
1969 details, as part of exposing the functionality of the I3C Controller and its Transfer Command/Response
1970 Interface:
1971 • Which Command Descriptor format is supported (per Section 7), including:
1972 • The size in of the Command Descriptor and Response Descriptor (in DWORDs)
1973 • Whether it supports certain Transfer Command types in the Command Descriptor format that are
1974 defined as optional
1975 • Which I3C Modes (i.e., SDR or HDR) are supported, and whether there might be limitations on any
1976 I3C Transfer Command options that apply to certain modes
1977 • Whether it defines any specific Command Descriptor forms for Address Assignment Commands or
1978 Internal Control Commands
1979 • Specific methods for enqueueing Command Descriptors and dequeuing Response Descriptors,
1980 including:
1981 • How to send TX Data (i.e., write into the data buffer for Transfer Commands that are Write-type
1982 transactions) and receive RX Data (i.e., read from data buffer for Transfer Commands that are Read-
1983 type transactions)
1984 • Whether the Application has a single operating context (i.e., entity that accesses the Command and
1985 Response queues) or whether it supports multiple operating contexts
1986 • How I3C In-Band Interrupts (IBIs) are received and reported to the Application, including:
1987 • Whether the Application also supports special handling of special IBIs, including Pending Read
1988 Notifications (per [MIPI02] Section 5.1.6.2.2) that might be processed autonomously
1989 • Whether other internal aspects of the I3C Controller are configurable, either at initialization or
1990 during typical operation, including:
1991 • Internal registers, parameters or configuration fields that can be accessed and changed by the
1992 Application, or its upper layers (i.e., controlling software or other agents in a stack)
1993 • Whether the Application has optional methods for handling transitions between I3C Modes and
1994 transfer rates, or alternate handling of the TOC field (i.e., end of sequence) as mentioned in
1995 Section 6.2.5
1996 • Whether the I3C Controller starts new transfers to I3C Devices with an initial Broadcast Address (i.e.,
1997 START, 7’h7E, Repeated START) to ensure that I3C Targets have the opportunity to raise IBI Requests
1998 The exact mechanism for reporting these capabilities and other details is not defined in this I3C TCRI
1999 Specification. However, Applications may use a variety of methods, including registers, descriptors (i.e.,
2000 defined data structures) returned as part of detecting the I3C Controller and establishing a session, and other
2001 reporting or signaling interfaces.
Copyright © 2022 MIPI Alliance, Inc. 89
Public Release Edition

| Specification for I3C TCRI  |     |     |     | Version 1.0  |
| --------------------------- | --- | --- | --- | ------------ |
|                             |     |     |     | 24-May-2022  |
A.2  Support for DAT-based and Direct Transfer Commands (Format 1 and
Format 2)
2002  An Application may choose to support both options (i.e., DAT-based and Direct Commands), meaning that
it chooses to implement both Format 1 (see Section 7.1) and Format 2 (Section 7.2) of the Command
2003
2004  Descriptor and Response Descriptor. This might be useful for Applications that have limited DAT entries, or
2005  Applications that have multiple operating contexts (i.e., where the DAT is used for one context but not others).
In such Applications, these two Command and Response Descriptor formats can be interoperable, with some
2006
2007  modifications. To aid in the decoding of Command Descriptor field CMD_ATTR, the following table provides
2008  guidance on field values to uniquely identify both DAT-based and Direct Transfer Commands.
2009  Table 21 Guidance on CMD_ATTR Values for Command Descriptor Formats 1 and 2
| Code                             | Command Type  | Form       | CMD_ATTR  | Section  |
| -------------------------------- | ------------- | ---------- | --------- | -------- |
| Immediate Data Transfer Command  |               | DAT-based  | 0x1       | 7.1.2.1  |
I
(Required)
|     |     | Direct     | 0x5 (*)  | 7.2.2.1  |
| --- | --- | ---------- | -------- | -------- |
|     |     | DAT-based  | 0x0      | 7.1.2.2  |
Regular Transfer Command
R
| (Required)              |     | Direct     | 0x4 (*)  | 7.2.2.2  |
| ----------------------- | --- | ---------- | -------- | -------- |
| Combo Transfer Command  |     | DAT-based  | 0x3      | 7.1.2.3  |
C
(Optional)
|                                |     | Direct  | 0x6 (*)  | 7.2.2.3  |
| ------------------------------ | --- | ------- | -------- | -------- |
| M  Internal Control Command    |     | N/A     | 0x7      | N/A      |
| A  Address Assignment Command  |     | N/A     | 0x2      | N/A      |

Note:
2010
In Table 21 above, the Direct Transfer Command formats use different values for field CMD_ATTR
2011
2012  than the values defined in Table 15. This allows the I3C Controller to distinguish whether the
2013  enqueued Transfer Command is referring to a DAT entry by its index, or whether it directly contains
2014  the Target’s address. The Application could choose to allow both sets of Transfer Command types to
2015  be enqueued at any time, or the Application might choose to reserve certain Transfer Command
types for specific operating contexts (i.e., the primary set of queues vs. other autonomous logic within
2016
2017  the Application).

| 90  | Copyright © 2022 MIPI Alliance, Inc.  |     |     |     |
| --- | ------------------------------------- | --- | --- | --- |
  Public Release Edition

Version 1.0 Specification for I3C TCRI
24-May-2022
Participants
The list below includes those persons who participated in the Working Group that developed this
Specification and who consented to appear on this list.
Guruprasad Ardhanari, Intel Corporation Radu Pitigoi-Aron, Qualcomm
Mohammad Asad Javed, Intel Corporation Nicolas Pitre, BayLibre
Rajesh Bhaskar, Intel Corporation Guruprasad Ramachandra, Synopsys, Inc.
Anamitra Chakrabarti, Synopsys, Inc. Rob Santoro, MIPI Alliance (Team)
Rob Gough, Intel Corporation Matthew Schnoor, Intel Corporation
Chris Grigg, MIPI Alliance (Team) Katherine Valenti, MIPI Alliance (Team)
Takayuki Hirama, Sony Group Corporation Suresh Venkatachalam, Synopsys, Inc.
Paul Kimelman, NXP Semiconductors Kasper Wszolek, Intel Corporation
Makoto Nariya, Sony Group Corporation Qijie Yang, Intel Corporation
Pratap Neelashetty, Synopsys, Inc. Tadaaki Yuba, Sony Group Corporation
Laura Nixon, MIPI Alliance (Team) Fred Zhou, Intel Corporation
Tomasz Pielaszkiewicz, Intel Corporation 2018
Copyright © 2022 MIPI Alliance, Inc. 91
Public Release Edition

Specification for I3C TCRI Version 1.0
24-May-2022
This page intentionally left blank.
92 Copyright © 2022 MIPI Alliance, Inc.
Public Release Edition