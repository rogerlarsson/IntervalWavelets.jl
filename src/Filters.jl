# ------------------------------------------------------------
# Functions and types for interacting with interior filters

struct InteriorFilter
	van_moment::Int64
	filter::OffsetVector{Float64, Vector{Float64}}

	function InteriorFilter(p, filter)
		if p >= 0
			new(p, filter)
		else
			throw(AssertionError("Not a valid interior filter"))
		end
	end
end

function Base.show(io::IO, IF::InteriorFilter)
	S = support(IF)
	println(io, "Filter for Daubechies ", van_moment(IF), " scaling function on [", S[1], ", ", S[end], "]:")

	show(io, IF.filter)
end

function Base.getindex(h::InteriorFilter, idx::Int)
	if checkbounds(Bool, h.filter, idx)
		return h.filter[idx]
	else
		return 0.0
	end
end

"""
	ifilter(p::Int)

Internal Daubechies filter with `p` vanishing moments with the **normal** filters.

	ifilter(p::Int, true)

Internal Daubechies filter with `p` vanishing moments with the symmlet filters.
This is the default.
"""
function ifilter(p::Integer, symmlet::Bool=true)
	p < 1 && throw(DomainError())

	if symmlet && 1 < p <= 8
		filter = OffsetArray(INTERIOR_FILTERS[p], -p+1:p)
	else
		filter = OffsetArray(wavelet(WT.Daubechies{p}()).qmf, 0:2*p-1)
	end

	return InteriorFilter(p, filter)
end

# Returns a copy; otherwise e.g. scale!(coef(C), 2) will modify C.filter
coef(C::InteriorFilter) = copy(C.filter)

van_moment(C::InteriorFilter) = C.van_moment
support(C::InteriorFilter) = linearindices(C.filter)
Base.length(C::InteriorFilter) = length(support(C))


# ------------------------------------------------------------
# Functions and types for interacting with boundary filters

immutable BoundaryFilter
	side::Char
	van_moment::Int64
	support::DaubSupport
	filter::Array{Vector{Float64}}

	function BoundaryFilter(side, p, S, F)
		if (side == 'L' || side == 'R') && (2 <= p <= 8)
			new(side, p, S, F)
		else
			throw(AssertionError("Not a valid boundary filter"))
		end
	end
end

left(B::BoundaryFilter) = left(B.support)
right(B::BoundaryFilter) = right(B.support)
side(B::BoundaryFilter) = B.side

function Base.show(io::IO, B::BoundaryFilter)
	S = support(B)
	p = van_moment(B)

	side = (B.side == 'L' ? "left" : "right")
	print(io, "Filters for ", side, " Daubechies ", p, " scaling function on [", left(S), ", ", right(S), "]:")

	for k in 0:p-1
		print(io, "\nk = ", k, ": ")
		show(io, bfilter(B,k))
	end
end

"""
	integers(B::BoundaryFilter)

The non-zero integers in the support of the boundary scaling function with filter `B`.
"""
function integers(B::BoundaryFilter)
	if side(B) == 'L'
		return right(support(B)):-1:1
	else side(B) == 'R'
		# The explicit step ensures type stability
		return left(support(B)):1:-1
	end
end

"""
	bfilter(p::Int, boundary::Char) -> BoundaryFilter

Return the boundary filters for the scaling functions with `p` vanishing moments.
`N` can be between 2 and 8.

`boundary` is either `'L'` or `'R'`.
"""
function bfilter(p::Integer, boundary::Char)
	2 <= p <= 8 || throw(AssertionError())

	if boundary == 'L'
		 return BoundaryFilter('L', p, DaubSupport(0, 2*p-1), LEFT_SCALING_FILTERS[p])
	elseif boundary == 'R'
		 return BoundaryFilter('R', p, DaubSupport(-2*p+1, 0), RIGHT_SCALING_FILTERS[p])
	else
		error("Boundary must be 'L' or 'R'")
	end
end

"""
	bfilter(BoundaryFilter, k::Int) -> Vector

Return the boundary filter for the `k`'th scaling function (0 <= `k` < the number of vanishing moments).
"""
function bfilter(B::BoundaryFilter, k::Int)
	0 <= k < van_moment(B) || throw(DomainError())
	return B.filter[k+1]
end


"""
	van_moment(F::BoundaryFilter) -> Integer

Return the number of vanishing moments of the boundary scaling functions defined by `F`.
"""
function van_moment(F::BoundaryFilter)
	return F.van_moment
end

"""
	support(B::BoundaryFilter)

Union of the supports of the boundary scaling functions defined by the filters `B`.
"""
function support(B::BoundaryFilter)
	B.support
end

"""
	support(B::BoundaryFilter, k)

Support of the `k`'th boundary scaling function defined by the filters `B`.
"""
function support(B::BoundaryFilter, k::Integer)
	0 <= k < (vm = van_moment(B)) || throw(DomainError())
	if B.side == 'L'
		return DaubSupport(0, vm+k)
	elseif B.side == 'R'
		return DaubSupport(-vm-k, 0)
	end
end


# ------------------------------------------------------------
# Boundary low pass filter coefficients for Daubechies wavelets
# http://www.pacm.princeton.edu/~ingrid/publications/54.txt


const INTERIOR_FILTERS = Dict{Int, Vector{Float64}}(
2 => [ 0.482962913145 ; 0.836516303738 ; 0.224143868042 ; -0.129409522551 ]
,
3 => [ .332670552950 ; .806891509311 ; .459877502118 ; -.135011020010 ; -.085441273882 ; .035226291882 ]
,
4 => [ 0.045570345896 ; -0.0178247014417 ; -0.140317624179 ; 0.421234534204 ; 1.13665824341 ; 0.703739068656 ; -0.0419109651251 ; -0.107148901418 ] / sqrt2
,
5 => [ 0.0276321529578 ; -0.0298424998687 ; -0.247951362613 ; 0.0234789231361 ; 0.89658164838 ; 1.02305296689 ; 0.281990696854 ; -0.0553441861166 ; 0.0417468644215 ; 0.0386547959548 ] / sqrt2
,
6 => [ -0.0110318675094 ; 0.00249992209279 ; 0.06325056266 ; -0.0297837512985  ; -0.102724969862 ; 0.477904371333 ; 1.11389278393 ; 0.694457972958 ; -0.0683231215866  ; -0.166863215412 ; 0.00493661237185 ; 0.0217847003266 ] / sqrt2
,
7 => [ 0.014521394762 ; 0.00567134268574 ; -0.152463871896 ; -0.198056706807 ; 0.408183939725 ; 1.08578270981 ; 0.758162601964  ; 0.0246656594886  ; -0.070078291222 ; 0.0960147679355 ; 0.043155452582 ; -0.0178704316511 ; -0.0014812259146 ; 0.0037926585342 ] / sqrt2
,
8 => [ 0.00267279339281 ; -0.000428394300246 ; -0.0211456865284 ; 0.00538638875377 ; 0.0694904659113 ; -0.0384935212634 ; -0.0734625087609 ; 0.515398670374 ; 1.09910663054 ; 0.68074534719 ; -0.0866536154058 ; -0.202648655286 ; 0.0107586117505 ; 0.0448236230437 ; -0.000766690896228 ; -0.0047834585115 ] / sqrt2
)

const LEFT_SCALING_FILTERS = Dict{Int, Array{Vector}}(
2 => Any[
[ 0.6033325119E+00 ; 0.6908955318E+00 ; -0.3983129977E+00 ]
,
[ 0.3751746045E-01 ; 0.4573276599E+00 ; 0.8500881025E+00 ; 0.2238203570E+00 ; -0.1292227434E+00 ]
]
,
3 => Any[
[ 0.3888997639E+00 ; -0.8820782813E-01 ; -0.8478413085E+00 ; 0.3494874367E+00 ]
,
[ -0.6211483178E+00 ; 0.5225273932E+00 ; -0.2000080031E+00 ; 0.3378673486E+00 ; -0.3997707705E+00 ; 0.1648201297E+00 ]
,
[ -0.9587863831E-02 ; 0.3712255319E-03 ; 0.3260097101E+00 ; 0.8016481645E+00 ; 0.4720552620E+00 ; -0.1400420809E+00 ; -0.8542510010E-01 ; 0.3521962365E-01 ]
]
,
4 => Any[
[ 0.9097539258E+00 ; 0.4041658894E+00 ; 0.8904031866E-01 ; -0.1198419201E-01 ; -0.3042908414E-01 ]
,
[ -0.2728514077E+00 ; 0.5090815232E+00 ; 0.6236424434E+00 ; 0.4628400863E+00 ; 0.2467476417E+00 ; -0.1766953329E-01 ; -0.4517364549E-01 ]
,
[ 0.1261179286E+00 ; -0.2308557268E+00 ; -0.5279923525E-01 ; 0.2192651713E+00 ; 0.4634807211E+00 ; 0.7001197140E+00 ; 0.4120325790E+00 ; -0.2622276250E-01 ; -0.6704069413E-01 ]
,
[ -0.2907980427E-01 ; 0.5992807229E-01 ; 0.6176427778E-02 ; -0.4021099904E-01 ; -0.3952587013E-01 ; -0.5259906257E-01 ; 0.3289494480E+00 ; 0.7966378967E+00 ; 0.4901130336E+00 ; -0.2943287768E-01 ; -0.7524762313E-01 ]
]
,
5 => Any[
[ 0.9302490657E+00 ; 0.3488878121E+00 ; 0.1098578445E+00 ; 0.2701025958E-01 ; 0.7897329608E-02 ; 0.7300852033E-02 ]
,
[ -0.3099501188E+00 ; 0.5987214008E+00 ; 0.6208411495E+00 ; 0.3720164550E+00 ; 0.1451060379E+00 ; 0.6263262144E-02 ; 0.1687072021E-01 ; 0.1562115518E-01 ]
,
[ 0.1138401479E+00 ; -0.3641831811E+00; 0.1228916167E-01 ; 0.4117590210E+00 ; 0.5954973448E+00 ; 0.5457944280E+00 ; 0.1756416185E+00 ; -0.1751671276E-01 ; 0.2376581050E-01 ; 0.2200554624E-01 ]
,
[ -0.4098816981E-01 ; 0.1431055982E+00 ; -0.6777711666E-01 ; -0.1740980466E+00 ; -0.9559132536E-01 ; 0.1512981220E+00 ; 0.6357421629E+00 ; 0.6823643465E+00 ; 0.1963091141E+00 ; -0.3301996982E-01 ; 0.2833562039E-01 ; 0.2623688365E-01 ]
,
[ 0.7965029532E-02 ; -0.2796122002E-01 ; 0.1706238600E-01 ; 0.2928655475E-01 ; 0.2857806991E-02 ; -0.4686793277E-01 ; -0.1702677471E+00 ; 0.3028147873E-01 ; 0.6351733467E+00 ; 0.7207789094E+00 ; 0.1995469939E+00 ; -0.3864256419E-01 ; 0.2947288315E-01 ; 0.2728991267E-01 ]
]
,
6 => Any[
[ 0.9231184460E+00 ; 0.3781064509E+00 ; 0.6815972396E-01 ; -0.1063392935E-01 ; -0.9724819798E-02 ; 0.1297887318E-02 ; 0.5723757426E-02 ]
,
[ -0.2868924125E+00 ; 0.5940469387E+00 ; 0.6609604336E+00 ; 0.3412988002E+00 ; 0.9716877076E-01 ; -0.1860855577E-01 ; -0.4013700006E-01 ; 0.1537307481E-02 ; 0.6783960390E-02 ]
,
[ 0.1472870932E+00 ; -0.3468945123E+00 ; 0.6221043773E-01 ; 0.4938022108E+00 ; 0.5849105895E+00 ; 0.4598788833E+00 ; 0.2274224529E+00 ; -0.2788953680E-01 ; -0.6367943024E-01 ; 0.2177711568E-02 ; 0.9609989671E-02 ]
,
[ -0.8324138021E-01 ; 0.2035630921E+00 ; -0.8289131955E-01 ; -0.1939904105E+00 ; -0.1908457968E-01 ; 0.2636403540E+00 ; 0.5123094150E+00 ; 0.6538041187E+00 ; 0.3695601186E+00 ; -0.3993953251E-01 ; -0.9479455728E-01 ; 0.2986558645E-02 ; 0.1317933842E-01 ]
,
[ 0.3164853364E-01 ; -0.8214471961E-01 ; 0.4327551059E-01 ; 0.6830653932E-01 ; -0.4840048148E-02 ; -0.7320834090E-01 ; -0.5786918156E-01 ; 0.2055855208E-01 ; 0.4001944206E+00 ; 0.7644983569E+00 ; 0.4653802512E+00 ; -0.4686421163E-01 ; -0.1137136979E+00 ; 0.3413297317E-02 ; 0.1506248690E-01 ]
,
[ -0.5550804971E-02 ; 0.1471087926E-01 ; -0.8859117912E-02 ; -0.1158923365E-01 ; 0.1569832259E-02 ; 0.1157111171E-01 ; 0.7445526684E-02 ; 0.2902493903E-01 ; -0.2999940975E-01 ; -0.6576340468E-01 ; 0.3438258786E+00 ; 0.7867130346E+00 ; 0.4895844920E+00 ; -0.4825468670E-01 ; -0.1177993251E+00 ; 0.3488475665E-02 ; 0.1539424027E-01 ]
]
,
7 => Any[
[ 0.9426568713E+00 ; 0.2691475418E+00 ; 0.1685897688E+00 ; 0.9379442214E-01 ; 0.4001600171E-01 ; 0.1057520816E-01 ; -0.1804517915E-02 ; 0.4620417362E-02 ]
,
[ -0.3237338194E+00 ; 0.6746802222E+00 ; 0.5985769136E+00 ; 0.2331427899E+00 ; 0.7615188825E-02 ; 0.8787238208E-01 ; 0.1327822780E+00 ; -0.4208296665E-01 ; -0.4763766998E-02 ; 0.1219755973E-01 ]
,
[ -0.2713311808E-01 ; -0.2899110477E+00 ; 0.6661404639E-01 ; 0.7251175151E+00 ; 0.5750729858E+00 ; 0.4362186445E-01 ; -0.1857980605E+00 ; 0.1201045634E+00 ; 0.5011061230E-01 ; -0.2991531277E-01 ; -0.1573393605E-02 ; 0.4028652635E-02 ]
,
[ 0.2428297386E-01 ; -0.1012534619E-01 ; -0.1589124403E+00 ; -0.1400872185E+00 ; 0.3332116140E+00 ; 0.7053065273E+00 ; 0.5793528972E+00 ; 0.3896614469E-02 ; -0.5955471765E-01 ; 0.7479188863E-01 ; 0.3081374376E-01 ; -0.1340206604E-01 ; -0.1047350551E-02 ; 0.2681726647E-02 ]
,
[ 0.2396415492E-02 ; -0.2199441967E-01 ; 0.3831273498E-01 ; 0.8416826933E-02 ; -0.1404553727E+00 ; -0.9975512873E-01 ; 0.2671255526E+00 ; 0.7725679637E+00 ; 0.5400947777E+00 ; 0.1395136806E-01 ; -0.4947167749E-01 ; 0.6809969285E-01 ; 0.3044230228E-01 ; -0.1259630803E-01 ; -0.1045026849E-02 ; 0.2675776840E-02 ]
,
[ -0.9493922980E-03 ; 0.8445740060E-02 ; -0.8462283108E-02 ; -0.3100522289E-02 ; 0.2269052507E-01 ; -0.9675176425E-02 ; -0.1013545517E+00 ; -0.1405275956E+00 ; 0.2877816730E+00 ; 0.7686169120E+00 ; 0.5358841401E+00 ; 0.1743190445E-01 ; -0.4949055461E-01 ; 0.6785067390E-01 ; 0.3050565786E-01 ; -0.1262873733E-01 ; -0.1047102354E-02 ; 0.2681091142E-02 ]
,
[ 0.1364120169E-03 ; -0.1153014522E-02 ; 0.1050196147E-02 ; 0.6396328807E-03 ; -0.1940525665E-02 ; 0.1962825019E-02 ; 0.9431646581E-02 ; 0.4027633417E-02 ; -0.1076854888E+00 ; -0.1401281648E+00 ; 0.2886799721E+00 ; 0.7677614604E+00 ; 0.5360881498E+00 ; 0.1744975917E-01 ; -0.4954996630E-01 ; 0.6789074612E-01 ; 0.3051526119E-01 ; -0.1263602514E-01 ; -0.1047379021E-02 ; 0.2681799545E-02 ]
]
,
8 => Any[
[ 0.9281136260E+00 ; 0.3668618286E+00 ; 0.6266997447E-01 ; -0.7647264163E-02 ; -0.5088004810E-02 ; 0.1171898539E-02 ; 0.1656055473E-02 ; -0.1929333000E-03 ; -0.1203653707E-02 ]
,
[ -0.2926634432E+00 ; 0.6373078980E+00 ; 0.6452435440E+00 ; 0.2965161471E+00 ; 0.5906254343E-01 ; -0.1366965641E-01 ; -0.1323318522E-01 ; 0.2213708145E-02 ; 0.8306912600E-02 ; -0.1892199826E-03 ; -0.1180561737E-02 ]
,
[ 0.1537394280E+00 ; -0.3933877381E+00 ; 0.1368645026E+00 ; 0.6064470308E+00 ; 0.5685338138E+00 ; 0.3166230149E+00 ; 0.9637901837E-01 ; -0.2215743488E-01 ; -0.4105959919E-01 ; 0.3062891878E-02 ; 0.1191510029E-01 ; -0.2473506634E-03 ; -0.1543244666E-02 ]
,
[ -0.9143117079E-01 ; 0.2571933236E+00 ; -0.1858137201E+00 ; -0.2318000501E+00 ; 0.1598859051E+00 ; 0.4871009258E+00 ; 0.5734443542E+00 ; 0.4450618899E+00 ; 0.2033090498E+00 ; -0.3331081673E-01 ; -0.6859620275E-01 ; 0.4406096842E-02 ; 0.1763488599E-01 ; -0.3388224811E-03 ; -0.2113946167E-02 ]
,
[ 0.5709470789E-01 ; -0.1665850443E+00 ; 0.1454047216E+00 ; 0.1015538648E+00 ; -0.1362852159E+00 ; -0.1769345243E+00 ; 0.8596479652E-02 ; 0.3062987789E+00 ; 0.5431752460E+00 ; 0.6140955155E+00 ; 0.3284966144E+00 ; -0.4723534035E-01 ; -0.1039762360E+00 ; 0.6053819361E-02 ; 0.2473853830E-01 ; -0.4480360998E-03 ; -0.2795340476E-02 ]
,
[ -0.2771885178E-01 ; 0.8389262409E-01 ; -0.8147463473E-01 ; -0.3866640174E-01 ; 0.7464550842E-01 ; 0.6920099668E-01 ; -0.2231653624E-01 ; -0.1020129060E+00 ; -0.6275852804E-01 ; 0.8683887629E-01 ; 0.4540741128E+00 ; 0.7328223558E+00 ; 0.4319437621E+00 ; -0.5734179466E-01 ; -0.1314896433E+00 ; 0.7195965493E-02 ; 0.2979946085E-01 ; -0.5190323961E-03 ; -0.3238293222E-02 ]
,
[ 0.8529185218E-02 ; -0.2624362023E-01 ; 0.2697489980E-01 ; 0.9748173003E-02 ; -0.2431726904E-01 ; -0.1901319060E-01 ; 0.8695522469E-02 ; 0.2729552258E-01 ; 0.1231155208E-01 ; 0.9187597846E-02 ; -0.4745631970E-01 ; -0.2924026466E-01 ; 0.3831732042E+00 ; 0.7723764353E+00 ; 0.4743837775E+00 ; -0.6082976218E-01 ; -0.1418145038E+00 ; 0.7565491348E-02 ; 0.3149214931E-01 ; -0.5401012058E-03 ; -0.3369743560E-02 ]
,
[ -0.1148179452E-02 ; 0.3567347972E-02 ; -0.3784785333E-02 ; -0.1105680377E-02 ; 0.3387180654E-02 ; 0.2395725348E-02 ; -0.1281174092E-02 ; -0.3407989030E-02 ; -0.1283416571E-02 ; -0.9841020551E-02 ; 0.6341196709E-02 ; 0.4619539219E-01 ; -0.2943416082E-01 ; -0.5094613096E-01 ; 0.3655480429E+00 ; 0.7770499808E+00 ; 0.4810695095E+00 ; -0.6126039684E-01 ; -0.1432436897E+00 ; 0.7606483137E-02 ; 0.3168981524E-01 ; -0.5420982042E-03 ; -0.3382203026E-02 ]
]
)


const RIGHT_SCALING_FILTERS = Dict{Int, Array{Vector}}(
2 => Any[
[ 0.8705087534E+00 ; 0.4348969980E+00 ; 0.2303890438E+00 ]
,
[ -0.1942334074E+00 ; 0.1901514184E+00 ; 0.3749553316E+00 ; 0.7675566693E+00 ; 0.4431490496E+00 ]
]
,
3 => Any[
[ 0.9096849943E+00 ; 0.3823606559E+00 ; 0.1509872153E+00 ; 0.5896101069E-01 ]
,
[ -0.2904078511E+00 ; 0.4189992290E+00 ; 0.4969643721E+00 ; 0.4907578307E+00 ; 0.4643627674E+00 ; 0.1914505442E+00 ]
,
[ 0.8183541840E-01 ; -0.1587582156E+00 ; -0.9124735623E-01 ; 0.6042558204E-03 ; 0.7702933610E-01 ; 0.5200601778E+00 ; 0.7642591993E+00 ; 0.3150938230E+00 ]
]
,
4 => Any[
[ 0.9154705188E+00 ; 0.3919142810E+00 ; 0.5947771124E-01 ; -0.2519180851E-01 ; 0.6437934569E-01 ]
,
[ -0.2191626469E+00 ; 0.4488001781E+00 ; 0.7540005084E+00 ; 0.3937758157E+00 ; -0.1581338944E+00 ; -0.1614201190E-01 ; 0.4126840881E-01 ]
,
[ 0.1290078289E-01 ; -0.1390716006E+00 ; 0.2921367950E-01 ; 0.4606168537E+00 ; 0.8164119742E+00 ; 0.2986473346E+00 ; -0.1027663536E+00 ; -0.1257488211E-01 ; 0.3214874197E-01 ]
,
[ -0.6775603652E-02 ; 0.1913244129E-01 ; -0.1770918425E-01 ; -0.6765916174E-01 ; -0.3023588481E-01 ; 0.4977920821E+00 ; 0.8039495996E+00 ; 0.2977111011E+00 ; -0.9910804055E-01 ; -0.1259895190E-01 ; 0.3221027840E-01 ]
]
,
5 => Any[
[ 0.6629994791E+00 ; 0.5590853114E+00 ; -0.3638895712E+00 ; -0.3190292420E+00 ; -0.8577516141E-01 ; 0.7938922949E-01 ]
,
[ -0.1615976602E+00 ; 0.7429922432E+00 ; 0.5771521705E+00 ; 0.2773360273E+00 ; 0.1530007177E-01 ; -0.1063942878E+00 ; -0.1216769629E-01 ; 0.1126647052E-01 ]
,
[ 0.2576681838E+00 ; -0.3995181391E-01 ; 0.1290658921E-01 ; 0.4163708782E+00 ; 0.6469374504E+00 ; 0.5608421202E+00 ; 0.4995700940E-02 ; -0.1569482750E+00 ; -0.2009485730E-01 ; 0.1860648984E-01 ]
,
[ -0.8955158953E-01 ; 0.3895616532E-01 ; 0.4751157158E-02 ; -0.6596188737E-01 ; 0.1520881337E-01 ; 0.2466644601E+00 ; 0.7199998123E+00 ; 0.6131240289E+00 ; 0.1537319456E-01 ; -0.1721947543E+00 ; -0.2083858871E-01 ; 0.1929513523E-01 ]
,
[ 0.1546583496E-01 ; -0.6559247482E-02 ; 0.2728093541E-02 ; 0.1830645747E-01 ; 0.1708296448E-01 ; 0.2156026058E-01 ; -0.3692524465E-01 ; 0.2045334663E+00 ; 0.7233635779E+00 ; 0.6327590443E+00 ; 0.1649999072E-01 ; -0.1751674471E+00 ; -0.2109311508E-01 ; 0.1953080958E-01 ]
]
,
6 => Any[
[ 0.9236675275E+00 ; 0.3793343885E+00 ; 0.4986459778E-01 ; -0.1688947163E-01 ; -0.3311806998E-02 ; 0.2804629640E-02 ; -0.1237553624E-01 ]
,
[ -0.2831955072E+00 ; 0.6209232596E+00 ; 0.6494435367E+00 ; 0.3279016732E+00 ; 0.4613465423E-01  ; -0.2201105042E-01 ; 0.4772996268E-01 ; 0.1811083865E-02 ; -0.7992103956E-02 ]
,
[ 0.1415889950E+00 ; -0.3264117354E+00 ; 0.5898718517E-01 ; 0.5662575494E+00 ; 0.6511436245E+00 ; 0.3434709841E+00 ; -0.6897565912E-01 ; -0.2139852264E-01 ; 0.4514540543E-01 ; 0.1807019829E-02 ; -0.7974169836E-02 ]
,
[ -0.4080929146E-01 ; 0.1251977353E+00 ; -0.9208945297E-01 ; -0.1815441604E+00 ; 0.7492893632E-01 ; 0.4921890166E+00 ; 0.7598885402E+00 ; 0.3298535864E+00 ; -0.6885203537E-01 ; -0.2056224689E-01 ; 0.4357038095E-01 ; 0.1729458762E-02 ; -0.7631901801E-02 ]
,
[ 0.1473338385E-01 ; -0.3879928306E-01 ; 0.3222685441E-01 ; 0.4181351746E-01 ; -0.4470160402E-01 ; -0.1143592801E+00 ; -0.3079264597E-01 ; 0.4953303341E+00 ; 0.7831063037E+00 ; 0.3365261769E+00 ; -0.7161554542E-01 ; -0.2096645980E-01 ; 0.4445995152E-01 ; 0.1762244193E-02 ; -0.7776580122E-02 ]
,
[ -0.2279778462E-02 ; 0.5934267127E-02 ; -0.4653920620E-02 ; -0.4697326198E-02 ; 0.7905498252E-02 ; 0.1478426761E-01 ; 0.6356609850E-03 ; -0.1184137622E+00 ; -0.4719524338E-01 ; 0.4914056494E+00 ; 0.7873827096E+00 ; 0.3378777169E+00 ; -0.7256793624E-01 ; -0.2105690525E-01 ; 0.4471373463E-01 ; 0.1767573251E-02 ; -0.7800096641E-02 ]
]
,
7 => Any[
[ 0.9091449027E+00 ; 0.4122956702E+00 ; 0.8463996964E-02 ; -0.4985469571E-01 ; -0.2885243693E-01 ; -0.8468475604E-02 ; 0.9290995299E-03 ; 0.2377975298E-02 ]
,
[ -0.2699308042E+00 ; 0.6287804833E+00 ; 0.6425124921E+00 ; 0.3295936378E+00 ; 0.9680040842E-01 ; -0.1505090528E-02 ; -0.2576996713E-01 ; -0.1663793375E-01 ; 0.7886583178E-03 ; 0.2019348750E-02 ]
,
[ 0.2157402688E+00 ; -0.3660961628E+00 ; 0.9979560410E-01 ; 0.5343306371E+00 ; 0.5651956498E+00 ; 0.3984651316E+00 ; 0.2006608171E+00 ; 0.3790996947E-01 ; -0.5279896883E-01 ; -0.3509616877E-01 ; 0.1600620645E-02 ; 0.4098367097E-02 ]
,
[ -0.1219999250E+00 ; 0.2497494925E+00 ; -0.1489636838E+00 ; -0.2314941689E+00 ; 0.4306729538E-01 ; 0.3349988297E+00 ; 0.5170449138E+00 ; 0.5314908191E+00 ; 0.3984867666E+00 ; 0.1134176909E+00 ; -0.8664578083E-01 ; -0.6206801690E-01 ; 0.2555164772E-02 ; 0.6542464174E-02 ]
,
[ 0.6643773700E-01 ; -0.1425076588E+00 ; 0.1150002072E+00 ; 0.1110261320E+00 ; -0.5456405522E-01 ; -0.1403852745E+00 ; -0.9002913124E-01 ; 0.9927107272E-01 ; 0.3252695570E+00 ; 0.5955739150E+00 ; 0.6177120462E+00 ; 0.2102093627E+00 ; -0.1207077310E+00 ; -0.9029360085E-01 ; 0.3498469159E-02 ; 0.8957782052E-02 ]
,
[ -0.2472698999E-01 ; 0.5451727819E-01 ; -0.4913268141E-01 ; -0.3543504434E-01 ; 0.2981657384E-01 ; 0.5443081267E-01 ; 0.3080352023E-01 ; -0.2311127518E-01 ; -0.2663146891E-01 ; -0.3986350788E-01 ; 0.1012109980E+00 ; 0.5654368499E+00 ; 0.7419995864E+00 ; 0.2730680885E+00 ; -0.1373359727E+00 ; -0.1050857718E+00 ; 0.3942767529E-02 ; 0.1009540190E-01 ]
,
[ 0.4060965940E-02 ; -0.9082349871E-02 ; 0.8675066430E-02 ; 0.5263347825E-02 ; -0.5426164014E-02 ; -0.8281419894E-02 ; -0.2928559727E-02 ; 0.7407888982E-02 ; 0.1392100926E-02 ; 0.2865053765E-01 ; 0.5527738563E-01 ; -0.5250033174E-01 ; 0.2337385282E-01 ; 0.5390029057E+00 ; 0.7666684946E+00 ; 0.2878132266E+00 ; -0.1399692009E+00 ; -0.1077108034E+00 ; 0.4008607630E-02 ; 0.1026398458E-01 ]
]
,
8 => Any[
[ 0.9280961080E+00 ; 0.3685482772E+00 ; 0.5169019500E-01 ; -0.1072856966E-01 ; -0.3547264354E-02 ; 0.1881724221E-02 ; 0.2253426546E-03 ; -0.4074549423E-03 ; 0.2542121693E-02 ]
,
[ -0.2880715337E+00 ; 0.6422316271E+00 ; 0.6540393284E+00 ; 0.2730170577E+00 ; 0.4300012686E-01 ; -0.1532507378E-01 ; -0.3095082211E-02 ; 0.3081063250E-02 ; -0.1192117285E-01 ; -0.2510321213E-03 ; 0.1566213637E-02 ]
,
[ 0.1554699662E+00 ; -0.3928508188E+00 ; 0.1655006354E+00 ; 0.6186900270E+00 ; 0.5757733437E+00 ; 0.2765573214E+00 ; 0.4215137090E-01 ; -0.2022141803E-01 ; 0.3170527734E-01 ; 0.2969565406E-02 ; -0.1133537854E-01 ; -0.2472629557E-03 ; 0.1542697449E-02 ]
,
[ -0.9273812077E-01 ; 0.2525480154E+00 ; -0.1903081753E+00 ; -0.2325263183E+00 ; 0.1951123754E+00 ; 0.5747752998E+00 ; 0.6031889613E+00 ; 0.3197987067E+00 ; -0.2318110629E-01 ; -0.2335276594E-01 ; 0.3904642048E-01 ; 0.3358324305E-02 ; -0.1296942483E-01 ; -0.2744734004E-03 ; 0.1712466040E-02 ]
,
[ 0.4096472123E-01 ; -0.1240767851E+00 ; 0.1278114403E+00 ; 0.7138489316E-01 ; -0.1584871307E+00 ; -0.1727866355E+00 ; 0.1143640280E+00 ; 0.5129116028E+00 ; 0.7137757767E+00 ; 0.3414317954E+00 ; -0.3881329228E-01 ; -0.2526829049E-01 ; 0.4424255303E-01 ; 0.3575822034E-02 ; -0.1394488775E-01 ; -0.2875903358E-03 ; 0.1794303867E-02 ]
,
[ -0.1790191282E-01 ; 0.5295161530E-01 ; -0.5704547538E-01 ; -0.1894676577E-01 ; 0.6968256270E-01 ; 0.4547075753E-01 ; -0.7337937479E-01 ; -0.1444748191E+00 ; -0.1409191494E-01 ; 0.4948704363E+00 ; 0.7618895951E+00 ; 0.3591100053E+00 ; -0.4810103061E-01 ; -0.2674149513E-01 ; 0.4783092078E-01 ; 0.3754819526E-02 ; -0.1470868404E-01 ; -0.2997260590E-03 ; 0.1870019815E-02 ]
,
[ 0.4842573875E-02 ; -0.1435818114E-01 ; 0.1564773617E-01 ; 0.3635704163E-02 ; -0.1807616145E-01 ; -0.7951972463E-02 ; 0.2177252927E-01 ; 0.3159516732E-01 ; -0.5393073080E-02 ; -0.1454356948E+00 ; -0.5484912621E-01 ; 0.4834662634E+00 ; 0.7753953496E+00 ; 0.3639514649E+00 ; -0.5141318290E-01 ; -0.2717238099E-01 ; 0.4899043649E-01 ; 0.3804055936E-02 ; -0.1492982098E-01 ; -0.3026846009E-03 ; 0.1888478444E-02 ]
,
[ -0.5886912723E-03 ; 0.1750384584E-02 ; -0.1931250902E-02 ; -0.3621632497E-03 ; 0.2085884179E-02 ; 0.6409242844E-03 ; -0.2736289413E-02 ; -0.3368917714E-02 ; 0.1038171472E-02 ; 0.3193936333E-01 ; 0.6823471193E-02 ; -0.1435014917E+00 ; -0.6098305316E-01 ; 0.4814477634E+00 ; 0.7771077176E+00 ; 0.3644295324E+00 ; -0.5192289139E-01 ; -0.2721779258E-01 ; 0.4913249792E-01 ; 0.3808651449E-02 ; -0.1495173150E-01 ; -0.3029170562E-03 ; 0.1889928755E-02 ]
]
)

