# Distributed under the terms of the GNU General Public License v2

EAPI=4

DESCRIPTION="Client tools for heroku"
HOMEPAGE="http://heroku.com"
SRC_URI="http://assets.heroku.com.s3.amazonaws.com/heroku-client/heroku-client.tgz"

LICENSE=""
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND+="dev-lang/ruby"
RDEPEND="${DEPEND}"

src_unpack() {
        unpack ${A}
}

S="${WORKDIR}/heroku-client"

src_install() {
	dodir "/usr/local/heroku"
	cp -r ${S}/* ${D}/usr/local/heroku
	dodir "/usr/local/bin"
	dosym /usr/local/heroku/bin/heroku /usr/local/bin/heroku
}

pkg_postinst() {
	einfo "To start using heroku, please create first an account at"
	einfo "${HOMEPAGE}, then run"
	einfo " \$ heroku login"
	einfo "this will ask for your login data and generate a public ssh key"
	einfo "for you if needed. To deploy your app do:"
	einfo " \$ cd ~/myapp"
	einfo " \$ heroku create"
}
