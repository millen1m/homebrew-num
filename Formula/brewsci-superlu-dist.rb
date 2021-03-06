class BrewsciSuperluDist < Formula
  desc "Distributed LU factorization for large linear systems"
  homepage "http://crd-legacy.lbl.gov/~xiaoye/SuperLU/"
  url "http://crd-legacy.lbl.gov/~xiaoye/SuperLU/superlu_dist_5.1.0.tar.gz"
  sha256 "30ac554a992441e6041c6fb07772da4fa2fa6b30714279de03573c2cad6e4b60"
  revision 1

  bottle do
    root_url "https://linuxbrew.bintray.com/bottles-num"
    sha256 "b66f68a56ba8874d061400b61a1159808ed196c63e552a76d4f78e7c69aa42e5" => :sierra
    sha256 "635b6a1f74c43b53ae2a3d6b074e6e3325e3ebe8d841b7fe5c70b1a07922a3fd" => :x86_64_linux
  end

  keg_only "formulae in brewsci/num are keg only"

  depends_on "cmake" => :build
  depends_on "brewsci/num/brewsci-parmetis"
  depends_on "gcc"
  depends_on "open-mpi"
  depends_on "openblas"

  def install
    # prevent linking errors on linuxbrew:
    ENV.deparallelize

    dylib_ext = OS.mac? ? "dylib" : "so"

    cmake_args = std_cmake_args
    cmake_args << "-DTPL_PARMETIS_LIBRARIES=#{Formula["brewsci-parmetis"].opt_lib}/libparmetis.#{dylib_ext};#{Formula["brewsci-metis"].opt_lib}/libmetis.#{dylib_ext}"
    cmake_args << "-DTPL_PARMETIS_INCLUDE_DIRS=#{Formula["brewsci-parmetis"].opt_include};#{Formula["brewsci-metis"].opt_include}"
    cmake_args << "-DCMAKE_C_FLAGS=-fPIC -O2"
    cmake_args << "-DBUILD_SHARED_LIBS=ON"
    cmake_args << "-DCMAKE_C_COMPILER=mpicc"
    cmake_args << "-DCMAKE_Fortran_COMPILER=mpif90"
    cmake_args << "-DCMAKE_INSTALL_PREFIX=#{prefix}"
    cmake_args << "-DTPL_BLAS_LIBRARIES=-L#{Formula["openblas"].opt_lib} -lopenblas"

    mkdir "build" do
      system "cmake", "..", *cmake_args
      system "make"
      system "make", "install"
      # system "make", "test"
    end

    doc.install "DOC/ug.pdf"
    pkgshare.install "EXAMPLE"
  end

  test do
    cp pkgshare/"EXAMPLE/dcreate_matrix.c", testpath
    cp pkgshare/"EXAMPLE/pddrive.c", testpath
    cp pkgshare/"EXAMPLE/g20.rua", testpath
    args = ["-I#{Formula["brewsci-superlu-dist"].opt_include}", "-L#{Formula["brewsci-superlu-dist"].opt_lib}", "-lsuperlu_dist"]
    ENV.prepend_path "LD_LIBRARY_PATH", opt_lib unless OS.mac?
    system "mpicc", "-o", "pddrive", "pddrive.c", "dcreate_matrix.c", *args
    output = shell_output("mpirun -np 4 ./pddrive -r 2 -c 2 g20.rua")
    accuracy = ((output.lines.grep /Sol  0/)[-1]).to_f
    assert accuracy < 1.0e-8
  end
end
