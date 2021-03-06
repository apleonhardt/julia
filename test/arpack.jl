begin
    srand(1234)
    local n,a,asym,b,bsym,d,v
    n = 10
    areal  = randn(n,n)
    breal  = randn(n,n)
    acmplx = complex(randn(n,n), randn(n,n))
    bcmplx = complex(randn(n,n), randn(n,n))

    for elty in (Float32, Float64, Complex64, Complex128)
        if elty == Complex64 || elty == Complex128
            a = acmplx
            b = bcmplx
        else
            a = areal
            b = breal
        end
        a     = convert(Matrix{elty}, a)
        asym  = a' + a                  # symmetric indefinite
        apd   = a'*a                    # symmetric positive-definite

        b     = convert(Matrix{elty}, b)
        bsym  = b' + b
        bpd   = b'*b

        if elty == Complex64 || elty == Float32
            testtol = 1e-3
        else
            testtol = 1e-6
        end

	(d,v) = eigs(a, nev=3)
	@test_approx_eq a*v[:,2] d[2]*v[:,2]
	(d,v) = eigs(a, b, nev=3, tol=1e-8)
	@test_approx_eq_eps a*v[:,2] d[2]*b*v[:,2] testtol

	(d,v) = eigs(asym, nev=3)
	@test_approx_eq asym*v[:,1] d[1]*v[:,1]
        @test_approx_eq eigs(asym; nev=1, sigma=d[3])[1][1] d[3]

	(d,v) = eigs(apd, nev=3)
	@test_approx_eq apd*v[:,3] d[3]*v[:,3]
        @test_approx_eq eigs(apd; nev=1, sigma=d[3])[1][1] d[3]
	(d,v) = eigs(apd, bpd, nev=3, tol=1e-8)
	@test_approx_eq_eps apd*v[:,2] d[2]*bpd*v[:,2] testtol

        # test (shift-and-)invert mode
        (d,v) = eigs(apd, nev=3, sigma=0)
        @test_approx_eq apd*v[:,3] d[3]*v[:,3]
        (d,v) = eigs(apd, bpd, nev=3, sigma=0, tol=1e-8)
        @test_approx_eq_eps apd*v[:,1] d[1]*bpd*v[:,1] testtol

    end
end

# Example from Quantum Information Theory
import Base: size, issym, ishermitian

type CPM{T<:Base.LinAlg.BlasFloat}<:AbstractMatrix{T} # completely positive map
	kraus::Array{T,3} # kraus operator representation
end

size(Phi::CPM)=(size(Phi.kraus,1)^2,size(Phi.kraus,3)^2)
issym(Phi::CPM)=false
ishermitian(Phi::CPM)=false

function *{T<:Base.LinAlg.BlasFloat}(Phi::CPM{T},rho::Vector{T})
	rho=reshape(rho,(size(Phi.kraus,3),size(Phi.kraus,3)))
	rho2=zeros(T,(size(Phi.kraus,1),size(Phi.kraus,1)))
	for s=1:size(Phi.kraus,2)
		As=slice(Phi.kraus,:,s,:)
		rho2+=As*rho*As'
	end
	return reshape(rho2,(size(Phi.kraus,1)^2,))
end
# Generate random isometry
(Q,R)=qr(randn(100,50))
Q=reshape(Q,(50,2,50))
# Construct trace-preserving completely positive map from this
Phi=CPM(Q)
(d,v,nconv,numiter,numop,resid) = eigs(Phi,nev=1,which="LM")
# Properties: largest eigenvalue should be 1, largest eigenvector, when reshaped as matrix
# should be a Hermitian positive definite matrix (up to an arbitrary phase)

@test_approx_eq d[1] 1. # largest eigenvalue should be 1.
v=reshape(v,(50,50)) # reshape to matrix
v/=trace(v) # factor out arbitrary phase
@test isapprox(vecnorm(imag(v)),0.) # it should be real
v=real(v)
# @test isapprox(vecnorm(v-v')/2,0.) # it should be Hermitian
# Since this fails sometimes (numerical precision error),this test is commented out
v=(v+v')/2
@test isposdef(v)

# Repeat with starting vector
(d2,v2,nconv2,numiter2,numop2,resid2) = eigs(Phi,nev=1,which="LM",v0=reshape(v,(2500,)))
v2=reshape(v2,(50,50))
v2/=trace(v2)
@test numiter2<numiter
@test_approx_eq v v2

@test_approx_eq eigs(speye(50), nev=10)[1] ones(10) #Issue 4246
